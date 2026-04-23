// FinancialDataReconciler.swift
// NomadFi
//
// Applies a ``FinancialDataSyncReport`` onto the app's existing
// SwiftData store (``Account`` + ``Transaction``). The reconciler
// respects four invariants, pinned by tests:
//
//   1. **Durable identity wins.** If an account carries a provider
//      kind + external account ID, a snapshot with the same pair is
//      always matched to that row. No heuristic is considered.
//   2. **Fallback is narrow.** Without a durable link, the reconciler
//      only matches a single existing account by institution name +
//      currency + account type. If more than one candidate matches,
//      the snapshot is counted as ambiguous and nothing is written —
//      the user can link manually from Settings.
//   3. **Transactions reuse the CSV deduper.** The same
//      ``TransactionImportDeduper`` that gates CSV imports gates
//      provider reconciliation, so we don't grow a second dedupe
//      system. Dedupe is always scoped to the linked account —
//      never cross-account.
//   4. **Nothing that isn't ours.** The reconciler refuses to mutate
//      tax review state, FX fields, or reward provenance, and it
//      never invents FX for a cross-currency snapshot.
//
// The reconciler is `@MainActor` because SwiftData's `ModelContext`
// is main-thread scoped in NomadFi. Callers outside the main actor
// dispatch once into the reconciler; the reconciler doesn't hop back
// out.

import Foundation
import OSLog
import SwiftData

/// Merges a ``FinancialDataSyncReport`` into the app's SwiftData
/// store. Every write goes through this single entry point so the
/// invariants above stay pinned in one place.
@MainActor
enum FinancialDataReconciler {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.Reconciler"
    )

    /// Applies `report` onto the store behind `modelContext`.
    /// `existingAccounts` and `existingTransactions` are passed in
    /// by the caller so tests can supply deterministic fixtures and
    /// production callers can pre-fetch from the active context.
    ///
    /// - Parameters:
    ///   - report: snapshots produced by
    ///     ``FinancialDataSyncCoordinator/syncAll(from:to:now:)``.
    ///   - modelContext: the active SwiftData context. The only
    ///     writer in this file.
    ///   - existingAccounts: current ``Account`` rows. Must be
    ///     complete — the reconciler does not fetch.
    ///   - existingTransactions: current ``Transaction`` rows,
    ///     across all accounts. Dedupe filters by linked account.
    ///   - homeCurrency: user's home currency, used to stamp
    ///     transactions where the snapshot currency matches.
    ///   - now: injected clock for deterministic timestamps in tests.
    @discardableResult
    static func apply(
        _ report: FinancialDataSyncReport,
        into modelContext: ModelContext,
        existingAccounts: [Account],
        existingTransactions: [Transaction],
        homeCurrency: CurrencyCode = .usd,
        now: Date = .now
    ) -> FinancialDataReconciliationResult {
        var result = FinancialDataReconciliationResult()
        var accountsBySnapshotID: [String: Account] = [:]
        var workingAccounts = existingAccounts

        for snapshot in report.accountSnapshots {
            let outcome = reconcileAccount(
                snapshot: snapshot,
                into: modelContext,
                existingAccounts: workingAccounts,
                now: now
            )
            switch outcome {
            case .matchedDurable(let account):
                accountsBySnapshotID[snapshot.id] = account
                result.matchedAccountsByDurableLink += 1
                if refreshAccount(account, from: snapshot, now: now) {
                    result.updatedAccounts += 1
                }
            case .matchedFallback(let account):
                accountsBySnapshotID[snapshot.id] = account
                result.matchedAccountsByFallback += 1
                stampProviderLink(on: account, from: snapshot, now: now)
                if refreshAccount(account, from: snapshot, now: now) {
                    result.updatedAccounts += 1
                }
            case .ambiguous:
                result.unresolvedAmbiguousSnapshots += 1
            case .created(let account):
                accountsBySnapshotID[snapshot.id] = account
                workingAccounts.append(account)
                stampProviderLink(on: account, from: snapshot, now: now)
                _ = refreshAccount(account, from: snapshot, now: now)
                result.createdAccounts += 1
            }
        }

        let txOutcome = reconcileTransactions(
            snapshots: report.transactionSnapshots,
            accountsBySnapshotID: accountsBySnapshotID,
            into: modelContext,
            existingTransactions: existingTransactions,
            homeCurrency: homeCurrency,
            now: now
        )
        result.insertedTransactions += txOutcome.inserted
        result.skippedDuplicateTransactions += txOutcome.duplicates
        result.unresolvedAmbiguousSnapshots += txOutcome.unresolved

        if result.createdAccounts > 0
            || result.updatedAccounts > 0
            || result.matchedAccountsByFallback > 0
            || result.insertedTransactions > 0
        {
            do {
                try modelContext.save()
            } catch {
                logger.error(
                    "Reconciler save failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return result
    }

    // MARK: - Account resolution

    private enum AccountMatchOutcome {
        case matchedDurable(Account)
        case matchedFallback(Account)
        case ambiguous
        case created(Account)
    }

    private static func reconcileAccount(
        snapshot: FinancialAccountSnapshot,
        into modelContext: ModelContext,
        existingAccounts: [Account],
        now: Date
    ) -> AccountMatchOutcome {
        let kindKey = snapshot.providerKind.logKey

        // 1. Durable match: provider kind + external ID.
        let durableMatches = existingAccounts.filter { account in
            account.providerLinkKindRawValue == kindKey
                && account.providerExternalAccountID == snapshot.id
        }
        if let exact = durableMatches.first, durableMatches.count == 1 {
            return .matchedDurable(exact)
        }
        if durableMatches.count > 1 {
            logger.info(
                "Ambiguous durable match for \(kindKey, privacy: .public):\(snapshot.id, privacy: .public)"
            )
            return .ambiguous
        }

        // 2. Narrow fallback: institution + currency + type. Only
        // when exactly one account matches.
        let fallback = existingAccounts.filter { account in
            !account.hasProviderLink
                && normalizedInstitution(account.institutionName) == normalizedInstitution(snapshot.institutionName)
                && account.currencyCodeRawValue == snapshot.currencyCode.rawValue
                && account.accountTypeRawValue == snapshot.accountType.rawValue
        }
        if let single = fallback.first, fallback.count == 1 {
            return .matchedFallback(single)
        }
        if fallback.count > 1 {
            return .ambiguous
        }

        // 3. No match — create a new row stamped with the provider
        // identity so the next pass uses the durable match path.
        let account = Account(
            name: snapshot.displayName,
            institutionName: snapshot.institutionName,
            accountType: snapshot.accountType,
            currencyCode: snapshot.currencyCode,
            jurisdiction: "",
            isFinanceKitLinked: snapshot.providerKind == .financeKit
        )
        modelContext.insert(account)
        return .created(account)
    }

    // MARK: - Account mutation

    /// Refreshes snapshot fields from the provider. Returns `true`
    /// when any field actually changed, so the caller can count a
    /// row as updated. Leaves untouched every field the snapshot
    /// does not cover (FX, rewards, tax, schedule).
    private static func refreshAccount(
        _ account: Account,
        from snapshot: FinancialAccountSnapshot,
        now: Date
    ) -> Bool {
        var changed = false

        if let value = snapshot.currentBalance, account.currentBalance != value {
            account.currentBalance = value
            changed = true
        }
        if let value = snapshot.creditLimit, account.creditLimit != value {
            account.creditLimit = value
            changed = true
        }
        if let value = snapshot.availableCredit, account.availableCredit != value {
            account.availableCredit = value
            changed = true
        }
        if let value = snapshot.statementBalance, account.statementBalance != value {
            account.statementBalance = value
            changed = true
        }

        if changed || snapshot.refreshedAt != nil {
            let updatedAt = snapshot.refreshedAt ?? now
            account.financialSnapshotUpdatedAt = updatedAt
            account.financialSnapshotSourceRawValue = snapshot.persistedSnapshotSource.rawValue
            account.providerLastSyncedAt = updatedAt
            account.lastUpdatedAt = now
        }

        return changed
    }

    private static func stampProviderLink(
        on account: Account,
        from snapshot: FinancialAccountSnapshot,
        now: Date
    ) {
        account.providerLinkKindRawValue = snapshot.providerKind.logKey
        account.providerExternalAccountID = snapshot.id
        account.providerInstitutionIdentifier = snapshot.institutionIdentifier
        account.providerLastSyncedAt = snapshot.refreshedAt ?? now
        if snapshot.providerKind == .financeKit {
            account.isFinanceKitLinked = true
        }
    }

    // MARK: - Transaction resolution

    private struct TransactionOutcome {
        var inserted: Int = 0
        var duplicates: Int = 0
        var unresolved: Int = 0
    }

    private static func reconcileTransactions(
        snapshots: [FinancialTransactionSnapshot],
        accountsBySnapshotID: [String: Account],
        into modelContext: ModelContext,
        existingTransactions: [Transaction],
        homeCurrency: CurrencyCode,
        now: Date
    ) -> TransactionOutcome {
        var outcome = TransactionOutcome()

        // Group by account to keep dedupe scoped. Snapshots whose
        // account didn't resolve are counted as unresolved — never
        // attached to an arbitrary fallback row.
        for snapshot in snapshots {
            guard let account = accountsBySnapshotID[snapshot.accountID] else {
                outcome.unresolved += 1
                continue
            }

            let sameAccount = existingTransactions.filter { transaction in
                transaction.account?.persistentModelID == account.persistentModelID
            }

            let parsed = ParsedImportedRow(
                lineNumber: 0,
                rawMerchantName: snapshot.merchantName,
                normalizedMerchantName: MerchantNormalizer.normalize(snapshot.merchantName),
                inferredCategory: snapshot.category,
                amount: snapshot.amount,
                currencyCode: snapshot.currencyCode,
                date: snapshot.date,
                externalTransactionID: snapshot.externalTransactionID,
                fingerprint: TransactionImportDeduper.fingerprint(
                    normalizedMerchant: MerchantNormalizer.normalize(snapshot.merchantName),
                    amount: snapshot.amount,
                    date: snapshot.date,
                    currency: snapshot.currencyCode
                )
            )

            if TransactionImportDeduper.duplicateReason(
                for: parsed,
                in: sameAccount
            ) != nil {
                outcome.duplicates += 1
                continue
            }

            let transaction = makeTransaction(
                from: snapshot,
                parsed: parsed,
                account: account,
                homeCurrency: homeCurrency,
                now: now
            )
            modelContext.insert(transaction)
            outcome.inserted += 1
        }

        return outcome
    }

    /// Builds a ``Transaction`` from a provider snapshot. Currency
    /// mismatch is represented honestly: the applied rate stays zero
    /// and a calm unverified provenance is attached. We never invent
    /// FX — see Phase 4 / `importedRateUnverified`.
    private static func makeTransaction(
        from snapshot: FinancialTransactionSnapshot,
        parsed: ParsedImportedRow,
        account: Account,
        homeCurrency: CurrencyCode,
        now: Date
    ) -> Transaction {
        let sameCurrency = parsed.currencyCode == homeCurrency
        let appliedRate = sameCurrency ? 1.0 : 0.0
        let convertedAmount = sameCurrency ? parsed.amount : 0.0

        return Transaction(
            merchantName: parsed.rawMerchantName,
            originalAmount: parsed.amount,
            originalCurrency: parsed.currencyCode,
            convertedAmount: convertedAmount,
            homeCurrency: homeCurrency,
            appliedExchangeRate: appliedRate,
            midMarketRate: 0,
            date: parsed.date,
            category: parsed.inferredCategory,
            jurisdiction: account.jurisdiction,
            notes: "",
            isTaxDeductible: false,
            isFinanceKitImported: snapshot.providerKind == .financeKit,
            createdAt: now,
            appliedRateProvenance: sameCurrency ? nil : SourceProvenance.importedRateUnverified(accessedAt: now),
            midMarketRateProvenance: nil,
            normalizedMerchantName: parsed.normalizedMerchantName,
            importSource: nil,
            externalTransactionID: parsed.externalTransactionID,
            importedAt: now,
            importFingerprint: parsed.fingerprint,
            taxSuggestionStatusRawValue: nil,
            taxSuggestionLastReviewedAt: nil,
            taxSuggestionCategoryRawValue: nil,
            providerKindRawValue: snapshot.providerKind.logKey,
            account: account,
            taxDocument: nil
        )
    }

    // MARK: - Helpers

    /// Collapses institution names to a comparable form: lowercased,
    /// trimmed, multiple whitespace collapsed. Keeps the narrow
    /// fallback match narrow and deterministic.
    private static func normalizedInstitution(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
