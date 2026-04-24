// PlaidSandboxIntegrationTests.swift
// NomadFi
//
// End-to-end integration between ``PlaidSandboxFinancialDataProvider``,
// the ``FinancialDataSyncCoordinator``, and the
// ``FinancialDataReconciler`` — exercised through a stub client that
// replays the shapes the local broker would return.
//
// Covers the three provable-in-code criteria from Phase 5D:
//
// 1. Plaid responses project onto `FinancialAccountSnapshot` /
//    `FinancialTransactionSnapshot` without structural rework
//    (`PlaidSandboxSnapshotMapperTests` pins the pure mapper; this
//    suite pins the adapter composition + coordinator fan-out).
// 2. `/transactions/sync` preserves the existing reconciler dedupe
//    invariants — a repeat sync with zero-diff added/modified rows
//    does not double-book.
// 3. `authorizationRequired` state projection into the Settings row
//    is correct when the broker URL is configured but no item handle
//    exists yet.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct PlaidSandboxIntegrationTests {

    // MARK: - Fixtures

    private nonisolated static let brokerURL = URL(string: "http://127.0.0.1:65535")!
    private nonisolated static let refreshedAt = Date(timeIntervalSince1970: 1_714_000_000)

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Account.self, Transaction.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private nonisolated static func sampleAccount() -> PlaidAccount {
        PlaidAccount(
            accountID: "acct_credit_1",
            name: "Plaid Sandbox Freedom",
            officialName: "Plaid Sandbox Freedom",
            mask: "0099",
            type: .credit,
            subtype: "credit card",
            balances: PlaidBalances(
                current: 50,
                available: 4_950,
                limit: 5_000,
                isoCurrencyCode: "USD",
                unofficialCurrencyCode: nil
            )
        )
    }

    private nonisolated static func sampleTransaction(
        id: String,
        amount: Double,
        merchant: String
    ) -> PlaidTransaction {
        PlaidTransaction(
            transactionID: id,
            accountID: "acct_credit_1",
            amount: amount,
            isoCurrencyCode: "USD",
            unofficialCurrencyCode: nil,
            date: "2026-04-15",
            authorizedDate: nil,
            merchantName: merchant,
            name: merchant,
            pending: false,
            personalFinanceCategory: PlaidPersonalFinanceCategory(
                primary: "FOOD_AND_DRINK",
                detailed: nil,
                confidenceLevel: "HIGH"
            ),
            paymentChannel: "in store"
        )
    }

    // MARK: - Availability / auth projection

    @Test("Adapter reports integrationNotImplemented when no broker URL is configured")
    func noBrokerURLMeansNotImplemented() async {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in StubPlaidSandboxClient() }
        )
        let availability = await provider.availability()
        let authorization = await provider.authorizationStatus()
        #expect(availability == .unavailable(reason: .integrationNotImplemented))
        #expect(authorization == .unavailable)
    }

    @Test("Broker configured but no item handle → availableNoConnections + notDetermined")
    func brokerConfiguredNoItem() async {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(Self.brokerURL)
        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in StubPlaidSandboxClient() }
        )
        #expect(await provider.availability() == .availableNoConnections)
        #expect(await provider.authorizationStatus() == .notDetermined)
    }

    @Test("Authorized once requestAuthorization has persisted an item handle")
    func requestAuthorizationPersistsItemHandle() async throws {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(Self.brokerURL)
        let stub = StubPlaidSandboxClient()
        stub.itemHandleToReturn = PlaidItemHandleResponse(
            itemID: "itm_sandbox_99",
            institutionID: "ins_109508",
            institutionName: "First Platypus Bank"
        )
        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in stub }
        )
        let status = try await provider.requestAuthorization()
        #expect(status == .authorized)
        #expect(config.itemID == "itm_sandbox_99")
        #expect(config.transactionsCursor == nil)
        #expect(await provider.availability() == .available)
    }

    // MARK: - Snapshot fan-out

    @Test("Accounts + /transactions/sync results cross the adapter into reconciler-ready snapshots")
    func snapshotFanOutThroughReconciler() async throws {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(Self.brokerURL)
        config.setItemID("itm_sandbox_99")

        let stub = StubPlaidSandboxClient()
        stub.accountsResponse = PlaidAccountsResponse(
            accounts: [Self.sampleAccount()],
            institutionName: "First Platypus Bank"
        )
        stub.syncPages = [
            PlaidTransactionsSyncResponse(
                added: [
                    Self.sampleTransaction(id: "txn_a", amount: 12.50, merchant: "Sample Cafe"),
                    Self.sampleTransaction(id: "txn_b", amount: 40.00, merchant: "Sample Market")
                ],
                modified: [],
                removed: [],
                nextCursor: "cursor_after_pull_1",
                hasMore: false
            )
        ]

        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in stub },
            clock: { Self.refreshedAt }
        )
        let coordinator = FinancialDataSyncCoordinator(providers: [provider])
        let report = await coordinator.syncAll(
            from: Date(timeIntervalSince1970: 1_700_000_000),
            to: Date(timeIntervalSince1970: 1_800_000_000),
            now: Self.refreshedAt
        )

        #expect(report.accountSnapshots.count == 1)
        #expect(report.transactionSnapshots.count == 2)
        let first = try #require(report.accountSnapshots.first)
        #expect(first.accountType == .creditCard)
        #expect(first.institutionName == "First Platypus Bank")
        #expect(first.creditLimit == 5_000)

        let outcome = try #require(report.outcomes.first)
        #expect(outcome.result == .succeeded)
        #expect(outcome.accountCount == 1)
        #expect(outcome.transactionCount == 2)

        let context = try makeContext()
        let reconciliation = FinancialDataReconciler.apply(
            report,
            into: context,
            existingAccounts: [],
            existingTransactions: [],
            homeCurrency: .usd
        )
        #expect(reconciliation.createdAccounts == 1)
        #expect(reconciliation.insertedTransactions == 2)
    }

    // MARK: - Repeat sync is a no-op (dedupe holds)

    @Test("Repeating the same /transactions/sync payload does not double-book via the reconciler")
    func repeatSyncIsDedupedByReconciler() async throws {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(Self.brokerURL)
        config.setItemID("itm_sandbox_99")

        let stub = StubPlaidSandboxClient()
        stub.accountsResponse = PlaidAccountsResponse(
            accounts: [Self.sampleAccount()],
            institutionName: "First Platypus Bank"
        )
        stub.syncPages = [
            PlaidTransactionsSyncResponse(
                added: [
                    Self.sampleTransaction(id: "txn_repeat", amount: 9.99, merchant: "Sample Cafe")
                ],
                modified: [],
                removed: [],
                nextCursor: "cursor_1",
                hasMore: false
            )
        ]
        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in stub },
            clock: { Self.refreshedAt }
        )
        let coordinator = FinancialDataSyncCoordinator(providers: [provider])
        let context = try makeContext()

        // First pass: inserts.
        let reportOne = await coordinator.syncAll(
            from: Date(timeIntervalSince1970: 1_700_000_000),
            to: Date(timeIntervalSince1970: 1_800_000_000),
            now: Self.refreshedAt
        )
        let first = FinancialDataReconciler.apply(
            reportOne,
            into: context,
            existingAccounts: [],
            existingTransactions: [],
            homeCurrency: .usd
        )
        #expect(first.createdAccounts == 1)
        #expect(first.insertedTransactions == 1)

        // Plaid's semantics: same external transaction ID → dedupe.
        // Replay the same payload and confirm no duplicate row lands.
        let existingAccounts = try context.fetch(FetchDescriptor<Account>())
        let existingTransactions = try context.fetch(FetchDescriptor<Transaction>())

        let reportTwo = await coordinator.syncAll(
            from: Date(timeIntervalSince1970: 1_700_000_000),
            to: Date(timeIntervalSince1970: 1_800_000_000),
            now: Self.refreshedAt
        )
        let second = FinancialDataReconciler.apply(
            reportTwo,
            into: context,
            existingAccounts: existingAccounts,
            existingTransactions: existingTransactions,
            homeCurrency: .usd
        )
        // Same account durable-linked, no new transaction.
        #expect(second.createdAccounts == 0)
        #expect(second.matchedAccountsByDurableLink == 1)
        #expect(second.insertedTransactions == 0)
        #expect(second.skippedDuplicateTransactions == 1)
    }

    // MARK: - Cursor finalization

    @Test("finalizeSync() only persists the cursor after a caller-confirmed commit")
    func cursorCommittedAfterReconcile() async throws {
        let storage = InMemoryStorage()
        let config = PlaidSandboxConfiguration(storage: storage)
        config.setBrokerURL(Self.brokerURL)
        config.setItemID("itm_sandbox_99")
        let stub = StubPlaidSandboxClient()
        stub.accountsResponse = PlaidAccountsResponse(
            accounts: [Self.sampleAccount()],
            institutionName: "First Platypus Bank"
        )
        stub.syncPages = [
            PlaidTransactionsSyncResponse(
                added: [],
                modified: [],
                removed: [],
                nextCursor: "cursor_after_empty_diff",
                hasMore: false
            )
        ]
        let provider = PlaidSandboxFinancialDataProvider(
            configuration: config,
            clientBuilder: { _ in stub }
        )

        let coordinator = FinancialDataSyncCoordinator(providers: [provider])
        _ = await coordinator.syncAll(
            from: Date(timeIntervalSince1970: 1_700_000_000),
            to: Date(timeIntervalSince1970: 1_800_000_000)
        )
        #expect(config.transactionsCursor == nil) // not yet committed
        await coordinator.finalizeAfterCommit()
        #expect(config.transactionsCursor == "cursor_after_empty_diff")
    }
}

// MARK: - Stub client

/// Deterministic in-test stub for ``PlaidSandboxClient``. Mutable
/// fields are plain `var`; the class is `@unchecked Sendable` and
/// every test touches it only from the main actor.
private final class StubPlaidSandboxClient: PlaidSandboxClient, @unchecked Sendable {

    var linkTokenToReturn: PlaidLinkTokenResponse = PlaidLinkTokenResponse(
        linkToken: "link-sandbox-token"
    )
    var itemHandleToReturn: PlaidItemHandleResponse = PlaidItemHandleResponse(
        itemID: "itm_stub",
        institutionID: "ins_109508",
        institutionName: "First Platypus Bank"
    )
    var accountsResponse: PlaidAccountsResponse = PlaidAccountsResponse(
        accounts: [],
        institutionName: "First Platypus Bank"
    )
    /// Pages served in FIFO order as successive `/transactions/sync`
    /// calls. The default is a single empty page.
    var syncPages: [PlaidTransactionsSyncResponse] = [
        PlaidTransactionsSyncResponse(
            added: [],
            modified: [],
            removed: [],
            nextCursor: "stub_cursor",
            hasMore: false
        )
    ]
    private var cursor = 0

    func createLinkToken() async throws -> PlaidLinkTokenResponse {
        linkTokenToReturn
    }
    func createSandboxItem() async throws -> PlaidItemHandleResponse {
        itemHandleToReturn
    }
    func exchangePublicToken(_ publicToken: String) async throws -> PlaidItemHandleResponse {
        itemHandleToReturn
    }
    func fetchAccounts(itemID: String) async throws -> PlaidAccountsResponse {
        accountsResponse
    }
    func syncTransactions(
        itemID: String,
        cursor: String?
    ) async throws -> PlaidTransactionsSyncResponse {
        defer { self.cursor = min(self.cursor + 1, syncPages.count - 1) }
        return syncPages[min(self.cursor, syncPages.count - 1)]
    }
}

// MARK: - In-memory configuration storage

/// Keychain-free storage used by the tests so nothing touches the
/// real iOS Keychain during CI.
private final class InMemoryStorage: PlaidSandboxConfigurationStorage, @unchecked Sendable {
    private var values: [KeychainService.Key: String] = [:]
    private let queue = TestLock()

    func loadString(_ key: KeychainService.Key) -> String? {
        queue.sync { values[key] }
    }
    func save(_ value: String, _ key: KeychainService.Key) {
        queue.sync { values[key] = value }
    }
    func delete(_ key: KeychainService.Key) {
        queue.sync { _ = values.removeValue(forKey: key) }
    }
}

/// Tiny `NSLock` wrapper so the in-memory storage above is safely
/// callable off the main actor. Tests run serially per suite on
/// Swift Testing, so this is defensive, not load-bearing.
private final class TestLock: @unchecked Sendable {
    private let lock = NSLock()
    func sync<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
