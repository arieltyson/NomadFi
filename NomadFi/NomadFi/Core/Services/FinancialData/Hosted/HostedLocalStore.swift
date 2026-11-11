import Foundation
import SwiftData

@MainActor
struct HostedLocalStore {
    static let provider = FinancialDataProviderKind.externalAggregator(identifier: "plaid_hosted")
    let container: ModelContainer

    struct Position: Sendable {
        let checkpoint: HostedCheckpoint
        let deviceID: UUID
        let bootstrapped: Bool
    }

    func position(ownerID: UUID, endpoint: URL) throws -> Position? {
        let context = ModelContext(container)
        guard let state = try findState(context, ownerID: ownerID, endpoint: endpoint) else { return nil }
        return .init(checkpoint: state.checkpoint, deviceID: state.deviceID, bootstrapped: state.lastAppliedAt != nil)
    }

    func apply(_ events: [HostedEvent], checkpoint: HostedCheckpoint, ownerID: UUID, endpoint: URL,
               homeCurrency: CurrencyCode, now: Date = .now, reviewedMigration: HostedLegacyMigration? = nil) throws -> Position {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            if let reviewedMigration {
                try reviewedMigration.applyMappings(in: context, owner: ownerID, service: endpoint, checkpoint: checkpoint, now: now)
            }
            let saved = try findState(context, ownerID: ownerID, endpoint: endpoint)
            let state = saved ?? HostedLocalState(ownerID: ownerID, endpoint: endpoint)
            guard let revision = UInt64(checkpoint.revision), let current = UInt64(state.revision),
                  checkpoint.offset >= -1, checkpoint.offset <= Int(Int32.max),
                  revision > current || (revision == current && checkpoint.offset >= state.eventOffset) else {
                throw HostedServiceError.obsoleteDelivery
            }
            let legacyKind: String? = FinancialDataProviderKind.externalAggregator(identifier: "plaid_sandbox").logKey
            let legacyAccounts = FetchDescriptor<Account>(predicate: #Predicate { $0.providerLinkKindRawValue == legacyKind })
            guard try context.fetchCount(legacyAccounts) == 0 else {
                throw HostedServiceError.migrationRequired
            }
            // Most deliveries carry nothing new. Record the checkpoint and
            // leave every account and transaction untouched and unloaded.
            if events.isEmpty, reviewedMigration == nil {
                if saved == nil { context.insert(state) }
                state.revision = checkpoint.revision
                state.eventOffset = checkpoint.offset
                state.lastAppliedAt = now
                try assignMissingCountries(in: context)
                try maskAccountNames(in: context)
                try context.save()
                return .init(checkpoint: state.checkpoint, deviceID: state.deviceID, bootstrapped: true)
            }
            // Only hosted records can match, and each is looked up by its
            // identity, so the work grows with this delivery rather than with
            // the square of the whole history.
            let hostedKind: String? = Self.provider.logKey
            let hostedAccounts = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.providerLinkKindRawValue == hostedKind }))
            let accountsByIdentity = Dictionary(grouping: hostedAccounts, by: { $0.providerExternalAccountID ?? "" })
            let changed = Set(events.map(\.identity))
            let previous = try state.ledger()
            var ledger = Dictionary(previous.map { ($0.identity, $0) }, uniquingKeysWith: { _, last in last })
            for event in events {
                guard ["account", "transaction"].contains(event.entityKind), !event.externalID.isEmpty else {
                    throw HostedServiceError.invalidResponse
                }
                if event.isRemoved, let prior = ledger[event.identity] {
                    ledger[event.identity] = .init(connectionID: event.connectionID, kind: event.kind,
                                                  externalID: event.externalID, payload: prior.payload, removed: true)
                } else { ledger[event.identity] = event }
            }
            let hostedTransactions = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.providerKindRawValue == hostedKind }))
            let transactionsByIdentity = Dictionary(grouping: hostedTransactions, by: { $0.externalTransactionID ?? "" })
            var mappedAccounts: [String: Account] = [:]
            // Accounts created in this pass; their transactions may have been
            // skipped earlier for want of an account, so they are revisited.
            var newAccountIdentities: Set<String> = []
            for event in ledger.values where event.entityKind == "account" {
                let matches = accountsByIdentity[event.identity] ?? []
                guard matches.count <= 1 else { throw HostedServiceError.invalidResponse }
                guard changed.contains(event.identity) else {
                    // Unchanged: keep it as it is, and let its transactions find it.
                    if !event.isRemoved, let account = matches.first, event.payload.currency.flatMap(CurrencyCode.init(rawValue:)) != nil,
                       accountType(event.payload) != nil {
                        mappedAccounts[event.identity] = account
                    }
                    continue
                }
                if event.isRemoved {
                    if let account = matches.first { clearBalances(account) }
                    continue
                }
                guard let rawCurrency = event.payload.currency, let currency = CurrencyCode(rawValue: rawCurrency),
                      let type = accountType(event.payload) else {
                    if let account = matches.first { clearBalances(account) }
                    continue
                }
                let account = matches.first ?? Account(name: SensitiveNumberRedactor.redactingName(event.payload.name ?? "Linked account"), institutionName: "",
                                                       accountType: type, currencyCode: currency)
                if matches.isEmpty {
                    context.insert(account)
                    newAccountIdentities.insert(event.identity)
                }
                account.providerLinkKindRawValue = Self.provider.logKey
                account.providerExternalAccountID = event.identity
                account.providerConnectionID = event.connectionID.uuidString
                account.currentBalance = try amount(event.payload.current)
                account.balance = account.currentBalance ?? 0
                account.creditLimit = type == .creditCard ? try amount(event.payload.limit) : nil
                account.availableCredit = type == .creditCard ? try amount(event.payload.available) : nil
                account.financialSnapshotUpdatedAt = timestamp(event.payload.balanceObservedAt)
                account.providerLastSyncedAt = timestamp(event.payload.fetchedAt)
                account.financialSnapshotSourceRawValue = Self.provider.persistedSnapshotSource.rawValue
                account.lastUpdatedAt = now
                mappedAccounts[event.identity] = account
            }
            var archive = state.archivedTransactionsData.isEmpty ? [HostedTransactionArchive]()
                : try JSONDecoder().decode([HostedTransactionArchive].self, from: state.archivedTransactionsData)
            let previousByID = Dictionary(previous.map { ($0.identity, $0) }, uniquingKeysWith: { _, last in last })
            for event in ledger.values where event.entityKind == "transaction" {
                let accountIdentity = event.payload.accountID.map { "\(event.connectionID.uuidString.lowercased())/account/\($0)" }
                guard changed.contains(event.identity) || accountIdentity.map(newAccountIdentities.contains) == true else { continue }
                let matches = transactionsByIdentity[event.identity] ?? []
                guard matches.count <= 1 else { throw HostedServiceError.invalidResponse }
                if event.isRemoved || event.payload.pending == true {
                    if let transaction = matches.first {
                        archive.removeAll { $0.identity == event.identity }
                        archive.append(archived(transaction, identity: event.identity))
                        transaction.taxDocument?.transaction = nil
                        transaction.taxDocument = nil
                        context.delete(transaction)
                    }
                    continue
                }
                guard let accountIdentity, let account = mappedAccounts[accountIdentity],
                      let rawCurrency = event.payload.currency, let currency = CurrencyCode(rawValue: rawCurrency),
                      let value = try amount(event.payload.amount), let day = day(event.payload.date) else { continue }
                let merchant = event.payload.merchantName ?? event.payload.name ?? "Transaction"
                let retained = archive.first { $0.identity == event.identity }
                let transaction = matches.first ?? retained.map { restore($0, account: account, context: context) }
                    ?? Transaction(merchantName: merchant, originalCurrency: currency, homeCurrency: homeCurrency, account: account)
                if matches.isEmpty { context.insert(transaction) }
                if (matches.isEmpty && retained == nil) || transaction.merchantName == previousByID[event.identity]?.payload.merchantName
                    || transaction.merchantName == previousByID[event.identity]?.payload.name {
                    transaction.merchantName = merchant
                }
                if (matches.isEmpty && retained == nil) || transaction.category == category(previousByID[event.identity]?.payload.category) {
                    transaction.categoryRawValue = category(event.payload.category).rawValue
                }
                transaction.originalAmount = value
                if transaction.originalCurrencyRawValue != rawCurrency { transaction.appliedExchangeRate = 0 }
                transaction.originalCurrencyRawValue = rawCurrency
                transaction.date = day
                transaction.normalizedMerchantName = MerchantNormalizer.normalize(transaction.merchantName)
                transaction.externalTransactionID = event.identity
                transaction.providerKindRawValue = Self.provider.logKey
                transaction.importedAt = now
                transaction.account = account
                if transaction.jurisdiction.isEmpty { transaction.jurisdiction = account.jurisdiction }
                if currency == transaction.homeCurrency {
                    transaction.appliedExchangeRate = 1
                    transaction.convertedAmount = value
                } else {
                    transaction.convertedAmount = value * transaction.appliedExchangeRate
                }
                archive.removeAll { $0.identity == event.identity }
            }
            try assignMissingCountries(in: context)
            try maskAccountNames(in: context)
            if saved == nil { context.insert(state) }
            state.ledgerData = try JSONEncoder().encode(ledger.values.sorted { $0.identity < $1.identity })
            state.archivedTransactionsData = try JSONEncoder().encode(archive)
            state.revision = checkpoint.revision
            state.eventOffset = checkpoint.offset
            state.lastAppliedAt = now
            try context.save()
            return .init(checkpoint: state.checkpoint, deviceID: state.deviceID, bootstrapped: true)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Masks the card or account ending a bank wrote into a linked
    /// account's name, for accounts saved before names were masked on
    /// arrival. Only names that would change are written.
    private func maskAccountNames(in context: ModelContext) throws {
        let hostedKind: String? = Self.provider.logKey
        let linked = try context.fetch(FetchDescriptor<Account>(
            predicate: #Predicate { $0.providerLinkKindRawValue == hostedKind }
        ))
        for account in linked {
            let masked = SensitiveNumberRedactor.redactingName(account.name)
            if masked != account.name { account.name = masked }
        }
    }

    /// Gives linked accounts that arrived without a country the one the
    /// person chose that uses the account's currency, and their
    /// transactions the same country, so they count under a flag on the
    /// Dashboard. A currency shared by two chosen countries is left for the
    /// person to decide, and a country they set is never changed.
    private func assignMissingCountries(in context: ModelContext) throws {
        let hostedKind: String? = Self.provider.logKey
        let unassigned = try context.fetch(FetchDescriptor<Account>(
            predicate: #Predicate { $0.providerLinkKindRawValue == hostedKind && $0.jurisdiction == "" }
        ))
        guard !unassigned.isEmpty else { return }
        let profiles = try context.fetch(FetchDescriptor<JurisdictionProfile>())
        var assigned = false
        for account in unassigned {
            guard let profile = Self.defaultCountry(forCurrency: account.currencyCodeRawValue, among: profiles) else { continue }
            account.jurisdiction = profile.countryCode
            account.jurisdictionProfile = profile
            assigned = true
        }
        guard assigned else { return }
        let uncounted = try context.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.providerKindRawValue == hostedKind && $0.jurisdiction == "" }
        ))
        for transaction in uncounted {
            if let country = transaction.account?.jurisdiction, !country.isEmpty { transaction.jurisdiction = country }
        }
    }

    /// The only chosen country that uses `currency`, if there is exactly one.
    static func defaultCountry(forCurrency currency: String, among profiles: [JurisdictionProfile]) -> JurisdictionProfile? {
        let matches = profiles.filter { $0.currencyCodeRawValue == currency }
        return matches.count == 1 ? matches[0] : nil
    }

    private func findState(_ context: ModelContext, ownerID: UUID, endpoint: URL) throws -> HostedLocalState? {
        let states = try context.fetch(FetchDescriptor<HostedLocalState>())
        guard states.count <= 1, states.allSatisfy({ $0.ownerID == ownerID.uuidString && $0.endpoint == endpoint.absoluteString }) else {
            throw HostedServiceError.ownerChanged
        }
        return states.first
    }
    private func clearBalances(_ account: Account) {
        account.balance = 0
        account.currentBalance = nil
        account.availableCredit = nil
        account.creditLimit = nil
        account.financialSnapshotUpdatedAt = nil
    }
    private func accountType(_ payload: HostedPayload) -> AccountType? {
        if payload.type == "credit", payload.subtype == "credit card" { return .creditCard }
        if payload.type == "depository" {
            if payload.subtype == "checking" { return .checking }
            if let subtype = payload.subtype, ["savings", "money market", "cd"].contains(subtype) { return .savings }
        }
        return nil
    }
    private func amount(_ string: String?) throws -> Double? {
        guard let string else { return nil }
        guard string.count <= 64, string.range(of: "^-?[0-9]+(\\.[0-9]{1,8})?$", options: .regularExpression) != nil,
              let decimal = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), !decimal.isNaN else {
            throw HostedServiceError.invalidResponse
        }
        let value = NSDecimalNumber(decimal: decimal).doubleValue
        guard value.isFinite else { throw HostedServiceError.invalidResponse }
        return value
    }
    private func timestamp(_ string: String?) -> Date? {
        guard let string else { return nil }
        return try? Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .colon))
    }
    private func day(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: "\(string)T00:00:00Z")
    }
    private func category(_ primary: String?) -> TransactionCategory {
        switch primary {
        case "INCOME": .income
        case "TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS": .transfer
        case "FOOD_AND_DRINK": .food
        case "TRANSPORTATION", "TRAVEL": .transport
        case "RENT_AND_UTILITIES": .utilities
        case "MEDICAL": .medical
        case "ENTERTAINMENT": .entertainment
        case "GENERAL_MERCHANDISE": .shopping
        default: .other
        }
    }
    private func archived(_ transaction: Transaction, identity: String) -> HostedTransactionArchive {
        .init(identity: identity, merchantName: transaction.merchantName, amount: transaction.originalAmount,
              currency: transaction.originalCurrencyRawValue, date: transaction.date, notes: transaction.notes,
              jurisdiction: transaction.jurisdiction, category: transaction.categoryRawValue,
              isTaxDeductible: transaction.isTaxDeductible, taxSuggestionStatus: transaction.taxSuggestionStatusRawValue,
              taxSuggestionReviewedAt: transaction.taxSuggestionLastReviewedAt, taxSuggestionCategory: transaction.taxSuggestionCategoryRawValue,
              convertedAmount: transaction.convertedAmount, homeCurrency: transaction.homeCurrencyRawValue,
              appliedRate: transaction.appliedExchangeRate, midMarketRate: transaction.midMarketRate,
              appliedProvenance: transaction.appliedExchangeRateProvenance, midMarketProvenance: transaction.midMarketRateProvenance,
              taxDocumentID: transaction.taxDocument?.persistentModelID)
    }

    private func restore(_ archived: HostedTransactionArchive, account: Account, context: ModelContext) -> Transaction {
        let transaction = Transaction(merchantName: archived.merchantName, originalAmount: archived.amount,
                                      originalCurrency: CurrencyCode(rawValue: archived.currency) ?? .usd,
                                      convertedAmount: archived.convertedAmount,
                                      homeCurrency: CurrencyCode(rawValue: archived.homeCurrency) ?? .usd,
                                      appliedExchangeRate: archived.appliedRate, midMarketRate: archived.midMarketRate,
                                      date: archived.date, category: TransactionCategory(rawValue: archived.category) ?? .other,
                                      jurisdiction: archived.jurisdiction, notes: archived.notes,
                                      isTaxDeductible: archived.isTaxDeductible,
                                      appliedRateProvenance: archived.appliedProvenance, midMarketRateProvenance: archived.midMarketProvenance,
                                      taxSuggestionStatusRawValue: archived.taxSuggestionStatus,
                                      taxSuggestionLastReviewedAt: archived.taxSuggestionReviewedAt,
                                      taxSuggestionCategoryRawValue: archived.taxSuggestionCategory, account: account)
        if let id = archived.taxDocumentID, let document = context.model(for: id) as? TaxDocument, document.transaction == nil {
            transaction.taxDocument = document
        }
        return transaction
    }
}
