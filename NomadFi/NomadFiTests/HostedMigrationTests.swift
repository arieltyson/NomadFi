import Foundation
import SwiftData
import Testing
@testable import NomadFi

@MainActor
struct HostedMigrationTests {
    private let owner = UUID()
    private let connection = UUID()
    private let endpoint = URL(string: "https://example.test")!
    private let checkpoint = HostedCheckpoint(revision: "1", offset: Int(Int32.max))
    private func setup() throws -> (ModelContainer, PersistentIdentifier, PersistentIdentifier) {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        let account = Account(name: "Synthetic CIBC account", currencyCode: .cad)
        account.providerLinkKindRawValue = HostedLegacyMigration.legacyKind
        account.providerExternalAccountID = "same-account"
        account.jurisdiction = "CA"
        context.insert(account)
        let record = Transaction(merchantName: "Synthetic purchase", originalCurrency: .cad, homeCurrency: .cad, account: account)
        record.providerKindRawValue = HostedLegacyMigration.legacyKind
        record.externalTransactionID = "same-transaction"
        record.notes = "Keep my classification"
        context.insert(record); try context.save()
        return (container, account.persistentModelID, record.persistentModelID)
    }
    private func events(accountID: String = "same-account", amount: String = "15") -> [HostedEvent] {
        [.init(connectionID: connection, kind: "account", externalID: accountID,
               payload: .init(name: "Provider name", type: "depository", subtype: "checking", currency: "CAD", current: "1000"), removed: false),
         .init(connectionID: connection, kind: "transaction", externalID: "same-transaction",
               payload: .init(name: "Provider transaction", currency: "CAD", accountID: accountID, amount: amount, date: "2026-10-01", pending: false), removed: false)]
    }
    @Test func reviewedStableIDsPreserveAccountsHistoryAndAnnotationsWithoutDuplication() throws {
        let (container, accountID, transactionID) = try setup()
        let review = try HostedLegacyMigration.prepare(events: events(), checkpoint: checkpoint, ownerID: owner, endpoint: endpoint, container: container)
        _ = try HostedLocalStore(container: container).apply(review.events, checkpoint: checkpoint, ownerID: owner,
            endpoint: endpoint, homeCurrency: .cad, reviewedMigration: review)
        let context = ModelContext(container)
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let records = try context.fetch(FetchDescriptor<Transaction>())
        #expect(accounts.count == 1); #expect(records.count == 1)
        #expect(accounts[0].persistentModelID == accountID); #expect(records[0].persistentModelID == transactionID)
        #expect(accounts[0].jurisdiction == "CA"); #expect(records[0].notes == "Keep my classification")
        #expect(records[0].originalAmount == 15)
        #expect(accounts[0].providerLinkKindRawValue == HostedLocalStore.provider.logKey)
    }
    @Test func changedProviderIDsNeverFallBackToNamesOrBalances() throws {
        let (container, _, _) = try setup()
        #expect(throws: HostedServiceError.migrationRequired) {
            try HostedLegacyMigration.prepare(events: events(accountID: "replacement-id"), checkpoint: checkpoint,
                ownerID: owner, endpoint: endpoint, container: container)
        }
    }
    @Test func malformedDataRollsBackIdentityMigrationAndCheckpointTogether() throws {
        let (container, _, _) = try setup()
        let review = try HostedLegacyMigration.prepare(events: events(amount: "not-money"), checkpoint: checkpoint,
            ownerID: owner, endpoint: endpoint, container: container)
        #expect(throws: HostedServiceError.invalidResponse) {
            try HostedLocalStore(container: container).apply(review.events, checkpoint: checkpoint, ownerID: owner,
                endpoint: endpoint, homeCurrency: .cad, reviewedMigration: review)
        }
        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<Account>()).first?.providerLinkKindRawValue == HostedLegacyMigration.legacyKind)
        #expect(try context.fetchCount(FetchDescriptor<HostedLocalState>()) == 0)
    }
    @Test func expiredReviewsAndWrongOwnersCannotChangeIdentities() throws {
        let (container, _, _) = try setup(), now = Date.now
        let review = try HostedLegacyMigration.prepare(events: events(), checkpoint: checkpoint,
            ownerID: owner, endpoint: endpoint, container: container, now: now)
        for (user, date) in [(UUID(), now), (owner, now.addingTimeInterval(901))] {
            #expect(throws: HostedServiceError.migrationRequired) {
                try HostedLocalStore(container: container).apply(review.events, checkpoint: checkpoint, ownerID: user,
                    endpoint: endpoint, homeCurrency: .cad, now: date, reviewedMigration: review)
            }
        }
    }
}
