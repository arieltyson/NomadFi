import Foundation
import OSLog
import SwiftData

/// Builds spending breakdowns and saves merchant rules in its own model
/// context, off the main thread, so a year of purchases never holds up
/// scrolling or animation. Only `Sendable` results cross back to the UI.
@ModelActor
actor SpendingBreakdownWorker {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "SpendingBreakdown")

    /// Where on-device suggestions are remembered.
    private var suggestionStore = SpendingSuggestionStore.standard
    private var cachedSuggestions: SpendingSuggestionStore.Suggestions?

    /// Bank detail codes by transaction identity, kept until the hosted
    /// ledger changes so it is decoded once rather than on every request.
    private var providerCodes: (signature: String, codes: [String: String])?

    // MARK: - Breakdown

    func breakdown(
        interval: SpendingInterval,
        homeCurrency: CurrencyCode,
        taxonomy: SpendingTaxonomy = .bundled
    ) throws -> SpendingBreakdown {
        let records = try records(in: interval)
        let classifier = SpendingClassifier(
            taxonomy: taxonomy,
            merchantRules: try merchantRules(),
            suggestions: suggestions()
        )
        return SpendingBreakdownComputer.breakdown(
            records: records,
            classifier: classifier,
            interval: interval,
            homeCurrency: homeCurrency
        )
    }

    // MARK: - Rules

    /// Saves which subcategory a merchant's purchases are, or with `nil`
    /// goes back to sorting the merchant automatically.
    func setRule(merchantKey: String, subcategoryID: String?) throws {
        let existing = try modelContext.fetch(
            FetchDescriptor<MerchantSpendingRule>(predicate: #Predicate { $0.merchantKey == merchantKey })
        )
        if let subcategoryID {
            if let rule = existing.first {
                rule.subcategoryID = subcategoryID
                rule.updatedAt = .now
                existing.dropFirst().forEach(modelContext.delete)
            } else {
                modelContext.insert(MerchantSpendingRule(merchantKey: merchantKey, subcategoryID: subcategoryID))
            }
        } else {
            existing.forEach(modelContext.delete)
        }
        try modelContext.save()
    }

    // MARK: - Suggestions

    /// Merchants already asked about, whether or not anything fit.
    func askedMerchantKeys() -> Set<String> {
        Set(suggestions().keys)
    }

    /// Remembers new suggestions; an empty ID records that nothing fit.
    func recordSuggestions(_ new: SpendingSuggestionStore.Suggestions) throws {
        let merged = suggestions().merging(new) { _, latest in latest }
        try suggestionStore.save(merged)
        cachedSuggestions = merged
    }

    /// Points the worker at another suggestion file, for tests.
    func useSuggestionStore(_ store: SpendingSuggestionStore) {
        suggestionStore = store
        cachedSuggestions = nil
    }

    private func suggestions() -> SpendingSuggestionStore.Suggestions {
        if let cachedSuggestions { return cachedSuggestions }
        let loaded = suggestionStore.load()
        cachedSuggestions = loaded
        return loaded
    }

    // MARK: - Reading

    /// The date of the earliest purchase that could count as spending, or
    /// `nil` when there is none, which bounds how far back one can go.
    func earliestSpendingDate() throws -> Date? {
        let income = TransactionCategory.income.rawValue
        let transfer = TransactionCategory.transfer.rawValue
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryRawValue != income && $0.categoryRawValue != transfer },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }

    /// The interval's possible spending, fetched with the date and
    /// category filters applied by the store.
    private func records(in interval: SpendingInterval) throws -> [SpendingRecord] {
        let start = interval.start
        let end = interval.end
        let income = TransactionCategory.income.rawValue
        let transfer = TransactionCategory.transfer.rawValue
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= start
                    && transaction.date < end
                    && transaction.categoryRawValue != income
                    && transaction.categoryRawValue != transfer
            }
        ))
        let codes = try providerCodesByIdentity()
        // Normalizing runs regular expressions, so each distinct name is
        // normalized once.
        var keysByName: [String: String] = [:]
        return transactions.compactMap { transaction in
            guard let currency = transaction.originalCurrency else { return nil }
            let merchantKey: String
            if let normalized = transaction.normalizedMerchantName, !normalized.isEmpty {
                merchantKey = normalized
            } else if let known = keysByName[transaction.merchantName] {
                merchantKey = known
            } else {
                merchantKey = MerchantNormalizer.normalize(transaction.merchantName)
                keysByName[transaction.merchantName] = merchantKey
            }
            return SpendingRecord(
                merchantKey: merchantKey,
                merchantName: transaction.merchantName,
                category: transaction.category ?? .other,
                providerCode: transaction.externalTransactionID.flatMap { codes[$0] },
                amount: transaction.originalAmount,
                currency: currency,
                date: transaction.date
            )
        }
    }

    private func merchantRules() throws -> [String: String] {
        let rules = try modelContext.fetch(
            FetchDescriptor<MerchantSpendingRule>(sortBy: [SortDescriptor(\.updatedAt)])
        )
        // The latest choice wins if a merchant somehow has two rules.
        return Dictionary(rules.map { ($0.merchantKey, $0.subcategoryID) }, uniquingKeysWith: { _, latest in latest })
    }

    /// The linked bank's detailed category for each synced purchase, read
    /// from the hosted ledger the sync already keeps.
    private func providerCodesByIdentity() throws -> [String: String] {
        let states = try modelContext.fetch(FetchDescriptor<HostedLocalState>())
        let signature = states.map { "\($0.ownerID)|\($0.revision)|\($0.eventOffset)" }.sorted().joined(separator: ",")
        if let providerCodes, providerCodes.signature == signature {
            return providerCodes.codes
        }
        var codes: [String: String] = [:]
        for state in states {
            do {
                for event in try state.ledger() where event.entityKind == "transaction" && !event.isRemoved {
                    if let code = event.payload.categoryDetail { codes[event.identity] = code }
                }
            } catch {
                // Without codes, purchases are still sorted by merchant.
                Self.logger.error("Hosted ledger unreadable for spending: \(error.localizedDescription, privacy: .public)")
            }
        }
        providerCodes = (signature, codes)
        return codes
    }
}
