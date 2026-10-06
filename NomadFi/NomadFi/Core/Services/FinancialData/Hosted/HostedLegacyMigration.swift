import Foundation
import SwiftData

struct HostedLegacyMigration: Identifiable, Sendable {
    struct Mapping: Sendable {
        let localID: PersistentIdentifier
        let accountID: PersistentIdentifier
        let originalExternalID: String
        let targetIdentity: String
        let connectionID: UUID
        let label: String
    }
    let id = UUID()
    let ownerID: UUID
    let endpoint: URL
    let checkpoint: HostedCheckpoint
    let events: [HostedEvent]
    let accounts: [Mapping]
    let transactions: [Mapping]
    let createdAt: Date

    static let legacyKind = FinancialDataProviderKind.externalAggregator(identifier: "plaid_sandbox").logKey

    @MainActor static func prepare(events: [HostedEvent], checkpoint: HostedCheckpoint, ownerID: UUID, endpoint: URL,
                                   container: ModelContainer, now: Date = .now) throws -> Self {
        let context = ModelContext(container)
        guard try context.fetchCount(FetchDescriptor<HostedLocalState>()) == 0 else { throw HostedServiceError.migrationRequired }
        let legacy = try context.fetch(FetchDescriptor<Account>()).filter { $0.providerLinkKindRawValue == legacyKind }
        guard !legacy.isEmpty else { throw HostedServiceError.migrationRequired }
        var mappings: [Mapping] = []
        for account in legacy {
            guard let externalID = account.providerExternalAccountID else { throw HostedServiceError.migrationRequired }
            let matches = events.filter { $0.entityKind == "account" && !$0.isRemoved && $0.externalID == externalID }
            guard matches.count == 1, let target = matches.first, target.payload.currency == account.currencyCodeRawValue,
                  (account.isCreditCard ? target.payload.type == "credit" : target.payload.type == "depository") else {
                throw HostedServiceError.migrationRequired
            }
            mappings.append(.init(localID: account.persistentModelID, accountID: account.persistentModelID, originalExternalID: externalID,
                targetIdentity: target.identity, connectionID: target.connectionID, label: account.name))
        }
        guard Set(mappings.map(\.targetIdentity)).count == mappings.count else { throw HostedServiceError.migrationRequired }
        var transactions: [Mapping] = []
        for record in try context.fetch(FetchDescriptor<Transaction>()) where record.providerKindRawValue == legacyKind {
            guard let account = record.account, let mapping = mappings.first(where: { $0.localID == account.persistentModelID }),
                  let externalID = record.externalTransactionID, !externalID.isEmpty else { throw HostedServiceError.migrationRequired }
            let identity = "\(mapping.connectionID.uuidString.lowercased())/transaction/\(externalID)"
            if let remote = events.first(where: { $0.identity == identity }), !remote.isRemoved,
               remote.payload.accountID != mapping.originalExternalID { throw HostedServiceError.migrationRequired }
            transactions.append(.init(localID: record.persistentModelID, accountID: account.persistentModelID, originalExternalID: externalID,
                targetIdentity: identity, connectionID: mapping.connectionID, label: "Retained transaction"))
        }
        guard Set(transactions.map(\.targetIdentity)).count == transactions.count else { throw HostedServiceError.migrationRequired }
        return .init(ownerID: ownerID, endpoint: endpoint, checkpoint: checkpoint, events: events,
                     accounts: mappings, transactions: transactions, createdAt: now)
    }

    @MainActor func applyMappings(in context: ModelContext, owner: UUID, service: URL, checkpoint: HostedCheckpoint, now: Date) throws {
        guard owner == ownerID, service == endpoint, checkpoint == self.checkpoint,
              now.timeIntervalSince(createdAt) >= 0, now.timeIntervalSince(createdAt) < 900,
              try context.fetchCount(FetchDescriptor<HostedLocalState>()) == 0 else { throw HostedServiceError.migrationRequired }
        let localAccounts = try context.fetch(FetchDescriptor<Account>()).filter { $0.providerLinkKindRawValue == Self.legacyKind }
        let localTransactions = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.providerKindRawValue == Self.legacyKind }
        guard Set(localAccounts.map(\.persistentModelID)) == Set(accounts.map(\.localID)),
              Set(localTransactions.map(\.persistentModelID)) == Set(transactions.map(\.localID)) else { throw HostedServiceError.migrationRequired }
        for mapping in accounts {
            guard let account = localAccounts.first(where: { $0.persistentModelID == mapping.localID }),
                  account.providerExternalAccountID == mapping.originalExternalID,
                  events.first(where: { $0.identity == mapping.targetIdentity })?.payload.currency == account.currencyCodeRawValue else {
                throw HostedServiceError.migrationRequired
            }
            account.providerLinkKindRawValue = HostedLocalStore.provider.logKey
            account.providerExternalAccountID = mapping.targetIdentity
            account.providerConnectionID = mapping.connectionID.uuidString
        }
        for mapping in transactions {
            guard let record = localTransactions.first(where: { $0.persistentModelID == mapping.localID }),
                  record.externalTransactionID == mapping.originalExternalID,
                  record.account?.persistentModelID == mapping.accountID,
                  record.account?.providerConnectionID == mapping.connectionID.uuidString else { throw HostedServiceError.migrationRequired }
            record.providerKindRawValue = HostedLocalStore.provider.logKey
            record.externalTransactionID = mapping.targetIdentity
        }
    }
}
