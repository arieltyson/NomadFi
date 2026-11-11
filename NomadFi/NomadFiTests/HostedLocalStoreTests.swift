import Foundation
import SwiftData
import Testing
@testable import NomadFi

@MainActor
struct HostedLocalStoreTests {
    private let owner = UUID()
    private let connection = UUID()
    private let endpoint = URL(string: "https://example.test")!
    private let end = Int(Int32.max)

    private func account(id: String = "account", current: String = "1000") -> HostedEvent {
        .init(connectionID: connection, kind: "account", externalID: id,
              payload: .init(name: "Synthetic account", type: "depository", subtype: "checking", currency: "CAD",
                             current: current, available: current, fetchedAt: "2026-10-05T12:00:00.000Z"), removed: false)
    }
    private func transaction(amount: String = "10", pending: Bool = false) -> HostedEvent {
        .init(connectionID: connection, kind: "transaction", externalID: "transaction",
              payload: .init(name: "Synthetic purchase", currency: "CAD", accountID: "account", amount: amount,
                             date: "2026-10-01", pending: pending), removed: false)
    }
    private func apply(_ events: [HostedEvent], to store: HostedLocalStore, revision: String = "1") throws {
        _ = try store.apply(events, checkpoint: .init(revision: revision, offset: end),
                            ownerID: owner, endpoint: endpoint, homeCurrency: .cad)
    }

    @Test func changesUpdateExistingRowsAndPreserveUserMetadata() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        try apply([account(), transaction()], to: store)
        let context = ModelContext(container)
        let existing = try #require(context.fetch(FetchDescriptor<Account>()).first)
        existing.jurisdiction = "CA"
        let purchase = try #require(context.fetch(FetchDescriptor<Transaction>()).first)
        purchase.notes = "Keep this user annotation"
        purchase.isTaxDeductible = true
        try context.save()
        try apply([account(current: "900"), transaction(amount: "20")], to: store, revision: "2")
        let refreshed = ModelContext(container)
        let accounts = try refreshed.fetch(FetchDescriptor<Account>())
        let transactions = try refreshed.fetch(FetchDescriptor<Transaction>())
        #expect(accounts.count == 1)
        #expect(accounts.first?.currentBalance == 900)
        #expect(accounts.first?.jurisdiction == "CA")
        #expect(accounts.first?.financialSnapshotUpdatedAt == nil)
        #expect(accounts.first?.providerLastSyncedAt != nil)
        #expect(transactions.count == 1)
        #expect(transactions.first?.originalAmount == 20)
        #expect(transactions.first?.convertedAmount == 20)
        #expect(transactions.first?.notes == "Keep this user annotation")
        #expect(transactions.first?.isTaxDeductible == true)
        #expect(try store.position(ownerID: owner, endpoint: endpoint)?.checkpoint.revision == "2")
    }

    @Test func removalArchivesAnnotationsAndDetachesTaxDocumentsBeforeDeletion() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        try apply([account(), transaction()], to: store)
        let context = ModelContext(container)
        let purchase = try #require(context.fetch(FetchDescriptor<Transaction>()).first)
        purchase.notes = "Retained receipt note"
        let receipt = TaxDocument(merchantName: "Synthetic receipt")
        context.insert(receipt)
        purchase.taxDocument = receipt
        try context.save()
        let removal = HostedEvent(connectionID: connection, kind: "removed_transaction", externalID: "transaction", payload: .init(), removed: true)
        try apply([removal], to: store, revision: "2")
        let refreshed = ModelContext(container)
        #expect(try refreshed.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try refreshed.fetchCount(FetchDescriptor<TaxDocument>()) == 1)
        #expect(try refreshed.fetch(FetchDescriptor<TaxDocument>()).first?.transaction == nil)
        let state = try #require(refreshed.fetch(FetchDescriptor<HostedLocalState>()).first)
        let archive = try JSONDecoder().decode([HostedTransactionArchive].self, from: state.archivedTransactionsData)
        #expect(archive.first?.notes == "Retained receipt note")
        try apply([transaction(amount: "12")], to: store, revision: "3")
        let restored = ModelContext(container)
        let returned = try #require(restored.fetch(FetchDescriptor<Transaction>()).first)
        #expect(returned.notes == "Retained receipt note")
        #expect(returned.taxDocument?.merchantName == "Synthetic receipt")
    }

    @Test func pendingRecordsRemainInLedgerWithoutInflatingPostedSpending() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        try apply([account(), transaction(pending: true)], to: store)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try context.fetch(FetchDescriptor<HostedLocalState>()).first?.ledger().count == 2)
    }

    @Test func malformedAmountsRollBackDataAndCheckpointTogether() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        #expect(throws: HostedServiceError.invalidResponse) { try apply([account(), transaction(amount: "10garbage")], to: store) }
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HostedLocalState>()) == 0)
    }

    @Test func oldDeliveryAndDifferentOwnersCannotReplaceLocalState() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        try apply([account()], to: store, revision: "2")
        #expect(throws: HostedServiceError.obsoleteDelivery) { try apply([account(current: "1")], to: store, revision: "1") }
        #expect(throws: HostedServiceError.ownerChanged) { try store.position(ownerID: UUID(), endpoint: endpoint) }
    }

    @Test func legacyPlaidAccountsRequireAnExplicitMigrationBeforeHostedImport() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        let legacy = Account(name: "Existing private account")
        legacy.providerLinkKindRawValue = FinancialDataProviderKind.externalAggregator(identifier: "plaid_sandbox").logKey
        context.insert(legacy)
        try context.save()
        #expect(throws: HostedServiceError.migrationRequired) { try apply([account()], to: .init(container: container)) }
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1)
    }

    @Test func versionOneDiskStoreMigratesWithoutLosingExistingAccounts() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "fixture.store")
        try autoreleasepool {
            let schema = Schema(versionedSchema: NomadFiSchemaV1.self)
            let old = try ModelContainer(for: schema, configurations: .init(schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(Account(name: "Preserved fixture", currencyCode: .cad))
            try context.save()
        }
        let schema = Schema(versionedSchema: NomadFiSchemaV2.self)
        let migrated = try ModelContainer(for: schema, migrationPlan: NomadFiMigrationPlan.self,
                                         configurations: .init(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(migrated)
        #expect(try context.fetch(FetchDescriptor<Account>()).first?.name == "Preserved fixture")
        #expect(try context.fetchCount(FetchDescriptor<HostedLocalState>()) == 0)
    }

    // MARK: - Work stays proportional to the delivery

    private func purchase(_ id: String, amount: String = "10", on accountID: String = "account") -> HostedEvent {
        .init(connectionID: connection, kind: "transaction", externalID: id,
              payload: .init(name: "Purchase \(id)", currency: "CAD", accountID: accountID, amount: amount,
                             date: "2026-10-01", pending: false), removed: false)
    }

    @Test func anEmptyDeliveryAdvancesTheCheckpointAndTouchesNothing() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try store.apply([account(), purchase("a")], checkpoint: .init(revision: "1", offset: end),
                            ownerID: owner, endpoint: endpoint, homeCurrency: .cad, now: first)
        _ = try store.apply([], checkpoint: .init(revision: "2", offset: end),
                            ownerID: owner, endpoint: endpoint, homeCurrency: .cad, now: first.addingTimeInterval(600))

        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.importedAt == first)
        #expect(try context.fetch(FetchDescriptor<Account>()).first?.lastUpdatedAt == first)
        #expect(try store.position(ownerID: owner, endpoint: endpoint)?.checkpoint.revision == "2")
    }

    @Test func aDeliveryOnlyRewritesTheRecordsItNames() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        let first = Date(timeIntervalSince1970: 1_800_000_000), later = first.addingTimeInterval(600)
        _ = try store.apply([account(), purchase("a"), purchase("b")], checkpoint: .init(revision: "1", offset: end),
                            ownerID: owner, endpoint: endpoint, homeCurrency: .cad, now: first)
        _ = try store.apply([purchase("b", amount: "25"), purchase("c")], checkpoint: .init(revision: "2", offset: end),
                            ownerID: owner, endpoint: endpoint, homeCurrency: .cad, now: later)

        let rows = try ModelContext(container).fetch(FetchDescriptor<Transaction>())
        let byName = Dictionary(uniqueKeysWithValues: rows.map { ($0.merchantName, $0) })
        #expect(rows.count == 3)
        #expect(byName["Purchase a"]?.importedAt == first, "An unnamed record is left exactly as it was")
        #expect(byName["Purchase b"]?.originalAmount == 25)
        #expect(byName["Purchase b"]?.importedAt == later)
        #expect(byName["Purchase c"]?.importedAt == later)
        #expect(byName.values.allSatisfy { $0.account != nil }, "New records still find an account that did not change")
    }

    @Test func aLargeHistoryMergesQuicklyAndLaterDeliveriesStayCheap() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        let history = [account()] + (0..<3000).map { purchase("t\($0)") }
        let clock = ContinuousClock()

        let bootstrap = try clock.measure {
            _ = try store.apply(history, checkpoint: .init(revision: "1", offset: end),
                                ownerID: owner, endpoint: endpoint, homeCurrency: .cad)
        }
        let delta = try clock.measure {
            _ = try store.apply([purchase("new")], checkpoint: .init(revision: "2", offset: end),
                                ownerID: owner, endpoint: endpoint, homeCurrency: .cad)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Transaction>()) == 3001)
        #expect(bootstrap < .seconds(10), "3,000 transactions took \(bootstrap)")
        #expect(delta < .seconds(2), "One new transaction over 3,000 took \(delta)")
    }

    // MARK: - Country assignment

    @Test func aLinkedAccountJoinsTheOnlyCountryThatUsesItsCurrency() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let setup = ModelContext(container)
        setup.insert(JurisdictionProfile(countryCode: "CA", countryName: "Canada", currencyCode: .cad))
        setup.insert(JurisdictionProfile(countryCode: "US", countryName: "United States", currencyCode: .usd))
        try setup.save()
        let store = HostedLocalStore(container: container)
        try apply([account(), purchase("a")], to: store)

        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<Account>()).first?.jurisdiction == "CA")
        #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.jurisdiction == "CA")
    }

    @Test func anExistingLinkedAccountIsBackfilledButAChosenCountryIsKept() throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let store = HostedLocalStore(container: container)
        try apply([account(), account(id: "second"), purchase("a")], to: store)
        let setup = ModelContext(container)
        setup.insert(JurisdictionProfile(countryCode: "CA", countryName: "Canada", currencyCode: .cad))
        let chosen = try #require(setup.fetch(FetchDescriptor<Account>()).first { $0.providerExternalAccountID?.hasSuffix("second") == true })
        chosen.jurisdiction = "TT"
        try setup.save()

        try apply([], to: store, revision: "2")

        let accounts = try ModelContext(container).fetch(FetchDescriptor<Account>())
        #expect(Set(accounts.map(\.jurisdiction)) == ["CA", "TT"])
        #expect(try ModelContext(container).fetch(FetchDescriptor<Transaction>()).first?.jurisdiction == "CA")
    }

    @Test func aCurrencySharedByTwoCountriesIsLeftUnassigned() {
        let profiles = [
            JurisdictionProfile(countryCode: "US", countryName: "United States", currencyCode: .usd),
            JurisdictionProfile(countryCode: "EC", countryName: "Ecuador", currencyCode: .usd),
        ]
        #expect(HostedLocalStore.defaultCountry(forCurrency: "USD", among: profiles) == nil)
        #expect(HostedLocalStore.defaultCountry(forCurrency: "CAD", among: profiles) == nil)
    }
}
