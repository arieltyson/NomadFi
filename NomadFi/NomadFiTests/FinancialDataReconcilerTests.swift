// FinancialDataReconcilerTests.swift
// NomadFi
//
// Phase 5B coverage for ``FinancialDataReconciler``. Pins the
// matching invariants the UI depends on:
// - durable provider identity wins;
// - fallback is narrow and refuses to merge when ambiguous;
// - repeat syncs are idempotent (no duplicate accounts, no
//   duplicate transactions);
// - transactions go through ``TransactionImportDeduper`` (external
//   ID + fingerprint) so the app keeps a single dedupe story;
// - the reconciler never cross-attaches a transaction to the wrong
//   account.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct FinancialDataReconcilerTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Account.self, Transaction.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private nonisolated static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private func makeAccountSnapshot(
        id: String = "apple-card-1",
        kind: FinancialDataProviderKind = .financeKit,
        institutionName: String = "Apple",
        accountType: AccountType = .creditCard,
        currency: CurrencyCode = .usd,
        currentBalance: Double? = 120,
        creditLimit: Double? = 5_000,
        availableCredit: Double? = 4_880,
        refreshedAt: Date
    ) -> FinancialAccountSnapshot {
        FinancialAccountSnapshot(
            id: id,
            providerKind: kind,
            institutionIdentifier: "apple",
            displayName: "Apple Card",
            institutionName: institutionName,
            accountType: accountType,
            currencyCode: currency,
            currentBalance: currentBalance,
            creditLimit: creditLimit,
            availableCredit: availableCredit,
            refreshedAt: refreshedAt
        )
    }

    private func makeTxSnapshot(
        id: String,
        accountID: String,
        externalID: String?,
        merchant: String,
        amount: Double,
        date: Date,
        currency: CurrencyCode = .usd,
        kind: FinancialDataProviderKind = .financeKit
    ) -> FinancialTransactionSnapshot {
        FinancialTransactionSnapshot(
            id: id,
            providerKind: kind,
            accountID: accountID,
            merchantName: merchant,
            amount: amount,
            currencyCode: currency,
            date: date,
            category: .other,
            externalTransactionID: externalID
        )
    }

    // MARK: - Durable identity wins

    @Test("Durable provider identity matches an existing Account exactly once")
    func durableMatchIsExact() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)

        let existing = Account(
            name: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 4_500,
            providerLinkKindRawValue: FinancialDataProviderKind.financeKit.logKey,
            providerExternalAccountID: "apple-card-1"
        )
        context.insert(existing)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)]
        )

        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [existing],
            existingTransactions: [],
            now: now
        )

        #expect(result.matchedAccountsByDurableLink == 1)
        #expect(result.createdAccounts == 0)
        #expect(result.updatedAccounts == 1)
        #expect(existing.currentBalance == 120)
        #expect(existing.creditLimit == 5_000)
        #expect(existing.financialSnapshotSourceRawValue == FinancialSnapshotSource.financeKit.rawValue)
    }

    @Test("Repeat syncs are idempotent — no duplicate account inserted")
    func repeatSyncIdempotent() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)
        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)]
        )

        let first = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [],
            existingTransactions: [],
            now: now
        )
        #expect(first.createdAccounts == 1)

        // Second pass: the reconciler must find the stamped account
        // via its durable link and not create a fresh row.
        let fetched = try context.fetch(FetchDescriptor<Account>())
        let second = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: fetched,
            existingTransactions: [],
            now: now
        )
        #expect(second.createdAccounts == 0)
        #expect(second.matchedAccountsByDurableLink == 1)
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1)
    }

    // MARK: - Fallback match

    @Test("Narrow fallback matches when exactly one account lines up")
    func fallbackMatchesUniqueCandidate() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)

        let existing = Account(
            name: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000
        )
        context.insert(existing)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [existing],
            existingTransactions: [],
            now: now
        )
        #expect(result.matchedAccountsByFallback == 1)
        #expect(result.createdAccounts == 0)
        #expect(existing.providerLinkKindRawValue == FinancialDataProviderKind.financeKit.logKey)
        #expect(existing.providerExternalAccountID == "apple-card-1")
        #expect(existing.isFinanceKitLinked)
    }

    @Test("Ambiguous fallback refuses to merge — counts as unresolved")
    func fallbackAmbiguousRefusesMerge() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)

        let first = Account(
            name: "Apple Card — Personal",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000
        )
        let second = Account(
            name: "Apple Card — Family",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000
        )
        context.insert(first)
        context.insert(second)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [first, second],
            existingTransactions: [],
            now: now
        )
        #expect(result.matchedAccountsByFallback == 0)
        #expect(result.matchedAccountsByDurableLink == 0)
        #expect(result.createdAccounts == 0)
        #expect(result.unresolvedAmbiguousSnapshots == 1)
        #expect(first.providerLinkKindRawValue == nil)
        #expect(second.providerLinkKindRawValue == nil)
    }

    // MARK: - Transaction dedupe

    @Test("Transactions reuse the import deduper on external-ID matches")
    func transactionExternalIDDedupe() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)
        let yesterday = Self.date(year: 2026, month: 4, day: 22)

        let account = Account(
            name: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000,
            providerLinkKindRawValue: FinancialDataProviderKind.financeKit.logKey,
            providerExternalAccountID: "apple-card-1"
        )
        context.insert(account)

        let existingTx = Transaction(
            merchantName: "Sample Cafe",
            originalAmount: -12.0,
            originalCurrency: .usd,
            convertedAmount: -12.0,
            homeCurrency: .usd,
            appliedExchangeRate: 1,
            midMarketRate: 1,
            date: yesterday,
            category: .food,
            jurisdiction: "US",
            externalTransactionID: "fk-tx-1",
            account: account
        )
        context.insert(existingTx)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)],
            transactionSnapshots: [
                makeTxSnapshot(
                    id: "fk-tx-1",
                    accountID: "apple-card-1",
                    externalID: "fk-tx-1",
                    merchant: "Sample Cafe",
                    amount: -12.0,
                    date: yesterday
                )
            ]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [account],
            existingTransactions: [existingTx],
            now: now
        )
        #expect(result.skippedDuplicateTransactions == 1)
        #expect(result.insertedTransactions == 0)
    }

    @Test("Transactions insert when dedupe finds nothing on the same account")
    func transactionInsertsWhenNovel() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)
        let yesterday = Self.date(year: 2026, month: 4, day: 22)

        let account = Account(
            name: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000,
            providerLinkKindRawValue: FinancialDataProviderKind.financeKit.logKey,
            providerExternalAccountID: "apple-card-1"
        )
        context.insert(account)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)],
            transactionSnapshots: [
                makeTxSnapshot(
                    id: "fk-tx-1",
                    accountID: "apple-card-1",
                    externalID: "fk-tx-1",
                    merchant: "Sample Cafe",
                    amount: -12.0,
                    date: yesterday
                )
            ]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [account],
            existingTransactions: [],
            now: now
        )
        #expect(result.insertedTransactions == 1)
        #expect(result.skippedDuplicateTransactions == 0)

        let stored = try context.fetch(FetchDescriptor<Transaction>())
        #expect(stored.count == 1)
        #expect(stored.first?.providerKindRawValue == FinancialDataProviderKind.financeKit.logKey)
        #expect(stored.first?.isFinanceKitImported == true)
    }

    @Test("Transactions whose account does not resolve are counted as unresolved")
    func transactionUnresolvedAccountIsCounted() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)

        let report = FinancialDataSyncReport(
            accountSnapshots: [],
            transactionSnapshots: [
                makeTxSnapshot(
                    id: "orphan-1",
                    accountID: "unknown-account",
                    externalID: "ext-x",
                    merchant: "Unknown",
                    amount: -1,
                    date: now
                )
            ]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [],
            existingTransactions: [],
            now: now
        )
        #expect(result.insertedTransactions == 0)
        #expect(result.unresolvedAmbiguousSnapshots == 1)
    }

    @Test("Cross-account dedupe is blocked — a same-fingerprint row on a different account still inserts")
    func dedupeIsScopedPerAccount() throws {
        let context = try makeContext()
        let now = Self.date(year: 2026, month: 4, day: 23)
        let yesterday = Self.date(year: 2026, month: 4, day: 22)

        let linkedAccount = Account(
            name: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            providerLinkKindRawValue: FinancialDataProviderKind.financeKit.logKey,
            providerExternalAccountID: "apple-card-1"
        )
        let unrelatedAccount = Account(
            name: "Unrelated Checking",
            institutionName: "Other Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        context.insert(linkedAccount)
        context.insert(unrelatedAccount)

        let unrelatedTx = Transaction(
            merchantName: "Sample Cafe",
            originalAmount: -12.0,
            originalCurrency: .usd,
            convertedAmount: -12.0,
            homeCurrency: .usd,
            appliedExchangeRate: 1,
            midMarketRate: 1,
            date: yesterday,
            category: .food,
            jurisdiction: "US",
            externalTransactionID: "fk-tx-1",
            account: unrelatedAccount
        )
        context.insert(unrelatedTx)

        let report = FinancialDataSyncReport(
            accountSnapshots: [makeAccountSnapshot(refreshedAt: now)],
            transactionSnapshots: [
                makeTxSnapshot(
                    id: "fk-tx-1",
                    accountID: "apple-card-1",
                    externalID: "fk-tx-1",
                    merchant: "Sample Cafe",
                    amount: -12.0,
                    date: yesterday
                )
            ]
        )
        let result = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [linkedAccount, unrelatedAccount],
            existingTransactions: [unrelatedTx],
            now: now
        )
        #expect(result.insertedTransactions == 1)
        #expect(result.skippedDuplicateTransactions == 0)
    }

    // MARK: - Empty / no-op

    @Test("Empty report is a no-op reconciliation")
    func emptyReportIsNoOp() throws {
        let context = try makeContext()
        let result = FinancialDataReconciler.apply(
            FinancialDataSyncReport(),
            into: context,
            existingAccounts: [],
            existingTransactions: []
        )
        #expect(result.isNoOp)
    }

    // MARK: - Provider kind round-trip

    @Test("Provider kinds round-trip through their persisted logKey")
    func providerKindRoundTrip() {
        let aggregator = FinancialDataProviderKind.externalAggregator(identifier: "acme")
        #expect(FinancialDataProviderKind.fromLogKey(aggregator.logKey) == aggregator)
        #expect(FinancialDataProviderKind.fromLogKey(FinancialDataProviderKind.manual.logKey) == .manual)
        #expect(FinancialDataProviderKind.fromLogKey(FinancialDataProviderKind.financeKit.logKey) == .financeKit)
        #expect(FinancialDataProviderKind.fromLogKey(nil) == nil)
        #expect(FinancialDataProviderKind.fromLogKey("") == nil)
        #expect(FinancialDataProviderKind.fromLogKey("bogus") == nil)
    }
}
