// PlaidSandboxFinancialDataProvider.swift
// NomadFi
//
// Phase 5D follow-through / pre-5E sandbox adapter. Bounded to the
// Plaid *sandbox* surface, routed through the local broker under
// `tools/plaid-sandbox-broker/`. The adapter is the only production
// target file that directly consumes Plaid-shaped DTOs; mapping onto
// NomadFi's provider-neutral snapshot contract happens here through
// `PlaidSandboxSnapshotMapper` so the rest of the app stays vendor-
// neutral.
//
// The adapter defaults to `.unavailable(reason: .integrationNotImplemented)`
// when the Keychain does not have a broker URL — which is the shipping
// default. Configuring a broker URL is an explicit developer action
// (documented in `tools/plaid-sandbox-broker/README.md`). That keeps
// the production path identical to today's behavior and makes the
// bakeoff-proof configuration opt-in.

import Foundation
import OSLog

/// Bounded Plaid sandbox adapter. Satisfies
/// ``FinancialDataProvider`` and delegates every Plaid-shaped call to
/// the local broker.
///
/// The struct is `Sendable`; transactions-sync cache state lives in a
/// private `PlaidSandboxSyncCache` actor so the provider can serve
/// per-account snapshot slices during a single coordinator pass
/// without re-fetching.
struct PlaidSandboxFinancialDataProvider: FinancialDataProvider {

    let kind: FinancialDataProviderKind = .externalAggregator(
        identifier: PlaidSandboxSnapshotMapper.providerIdentifier
    )

    private let clientBuilder: @Sendable (URL) -> any PlaidSandboxClient
    private let configuration: PlaidSandboxConfiguration
    private let cache: PlaidSandboxSyncCache
    private let clock: @Sendable () -> Date

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.PlaidSandbox"
    )

    /// Production initializer. Uses the Keychain-backed configuration
    /// and the HTTPS-over-URLSession client.
    init(
        configuration: PlaidSandboxConfiguration = PlaidSandboxConfiguration(),
        clientBuilder: (@Sendable (URL) -> any PlaidSandboxClient)? = nil,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.clientBuilder = clientBuilder ?? { url in
            LivePlaidSandboxClient(baseURL: url)
        }
        self.cache = PlaidSandboxSyncCache()
        self.clock = clock
    }

    // MARK: - FinancialDataProvider

    func availability() async -> FinancialDataProviderAvailability {
        guard configuration.brokerURL != nil else {
            return .unavailable(reason: .integrationNotImplemented)
        }
        if configuration.itemID == nil {
            return .availableNoConnections
        }
        return .available
    }

    func authorizationStatus() async -> FinancialDataAuthorizationStatus {
        guard configuration.brokerURL != nil else { return .unavailable }
        return configuration.itemID == nil ? .notDetermined : .authorized
    }

    /// For the sandbox proof this uses Plaid's dev-only
    /// `/sandbox/public_token/create` → `/item/public_token/exchange`
    /// bypass (wrapped by the broker). Real Link-SDK-driven consent
    /// is a deferred Phase 5E concern.
    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus {
        guard let url = configuration.brokerURL else {
            throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
        }
        let client = clientBuilder(url)
        let handle: PlaidItemHandleResponse
        do {
            handle = try await client.createSandboxItem()
        } catch let error as FinancialDataProviderError {
            throw error
        } catch {
            Self.logger.error(
                "Plaid sandbox item creation failed: \(error.localizedDescription, privacy: .public)"
            )
            throw FinancialDataProviderError.refreshFailed
        }
        configuration.setItemID(handle.itemID)
        configuration.setTransactionsCursor(nil)
        return .authorized
    }

    func connections() async -> [FinancialDataConnection] {
        let availability = await availability()
        switch availability {
        case .unavailable(let reason):
            return [
                FinancialDataConnection(
                    id: "plaid-sandbox",
                    providerKind: kind,
                    displayName: "Plaid sandbox",
                    status: .unavailable(reason: reason)
                )
            ]
        case .availableNoConnections:
            return [
                FinancialDataConnection(
                    id: "plaid-sandbox",
                    providerKind: kind,
                    displayName: "Plaid sandbox",
                    status: .notConnected
                )
            ]
        case .available:
            return [
                FinancialDataConnection(
                    id: "plaid-sandbox",
                    providerKind: kind,
                    displayName: "Plaid sandbox",
                    status: .connected
                )
            ]
        }
    }

    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] {
        try await ensureLinked()
        guard let url = configuration.brokerURL,
              let itemID = configuration.itemID
        else {
            throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
        }
        let client = clientBuilder(url)
        let now = clock()

        // Fetch transactions once per sync pass and cache them so the
        // coordinator's per-account calls serve filtered slices
        // without re-hitting the broker.
        await cache.clear()
        let accountsResponse: PlaidAccountsResponse
        let syncPayload: AggregatedSyncResult
        do {
            accountsResponse = try await client.fetchAccounts(itemID: itemID)
            syncPayload = try await paginateSync(
                client: client,
                itemID: itemID,
                initialCursor: configuration.transactionsCursor
            )
        } catch let error as FinancialDataProviderError {
            throw error
        } catch {
            throw FinancialDataProviderError.refreshFailed
        }

        await cache.store(syncPayload)

        let institutionName = accountsResponse.institutionName ?? "Plaid sandbox institution"
        return accountsResponse.accounts.compactMap { account in
            PlaidSandboxSnapshotMapper.mapAccount(
                account,
                institutionName: institutionName,
                refreshedAt: now
            )
        }
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        guard let sync = await cache.current() else {
            return []
        }
        let combined = sync.added + sync.modified
        let filtered = combined.filter { transaction in
            transaction.accountID == accountID
        }
        let snapshots = filtered.compactMap { transaction -> FinancialTransactionSnapshot? in
            PlaidSandboxSnapshotMapper.mapTransaction(transaction)
        }
        return snapshots.filter { snapshot in
            snapshot.date >= startDate && snapshot.date <= endDate
        }
    }

    /// Commits the new `/transactions/sync` cursor after the
    /// coordinator has successfully reconciled the last pass.
    /// Persisting the cursor only after a successful write matches
    /// Plaid's documented incremental-sync guidance:
    /// https://plaid.com/docs/transactions/sync/.
    func finalizeSync() async {
        guard let cursor = await cache.pendingCursor() else { return }
        configuration.setTransactionsCursor(cursor)
        await cache.clear()
    }

    // MARK: - Private

    private func ensureLinked() async throws {
        switch await availability() {
        case .unavailable(let reason):
            throw FinancialDataProviderError.providerUnavailable(reason)
        case .availableNoConnections:
            throw FinancialDataProviderError.providerUnavailable(.entitlementNotProvisioned)
        case .available:
            return
        }
    }

    private func paginateSync(
        client: any PlaidSandboxClient,
        itemID: String,
        initialCursor: String?
    ) async throws -> AggregatedSyncResult {
        var cursor = initialCursor
        var added: [PlaidTransaction] = []
        var modified: [PlaidTransaction] = []
        var removed: [PlaidRemovedTransaction] = []
        // Plaid documents `has_more: true` when the diff spills across
        // multiple pages. Cap the loop defensively so a misbehaving
        // sandbox cannot spin forever.
        for _ in 0..<Self.maxSyncPages {
            let page = try await client.syncTransactions(
                itemID: itemID,
                cursor: cursor
            )
            added.append(contentsOf: page.added)
            modified.append(contentsOf: page.modified)
            removed.append(contentsOf: page.removed)
            cursor = page.nextCursor
            if !page.hasMore { break }
        }
        return AggregatedSyncResult(
            added: added,
            modified: modified,
            removed: removed,
            nextCursor: cursor
        )
    }

    private static let maxSyncPages = 20
}

// MARK: - Supporting state

/// Aggregate of all `/transactions/sync` pages collected during one
/// coordinator pass. Value-typed so the cache actor can store it
/// under a single assignment.
struct AggregatedSyncResult: Sendable, Equatable {
    let added: [PlaidTransaction]
    let modified: [PlaidTransaction]
    let removed: [PlaidRemovedTransaction]
    let nextCursor: String?
}

/// Actor-backed cache so the sandbox adapter can serve multiple
/// `fetchTransactionSnapshots(accountID:…)` calls from one broker
/// round-trip without rerunning the `/transactions/sync` paginator.
actor PlaidSandboxSyncCache {
    private var snapshot: AggregatedSyncResult?

    func clear() { snapshot = nil }
    func store(_ result: AggregatedSyncResult) { snapshot = result }
    func current() -> AggregatedSyncResult? { snapshot }
    func pendingCursor() -> String? { snapshot?.nextCursor }
}
