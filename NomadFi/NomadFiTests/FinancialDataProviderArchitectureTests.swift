// FinancialDataProviderArchitectureTests.swift
// NomadFi
//
// Focused Phase 5A coverage for the ``FinancialDataProvider`` layer and
// the ``FinancialDataSyncCoordinator``. Every test is pure value-layer;
// no device / entitlement / network paths are exercised.
//
// Scope:
// - provider selection + fallback behaviour;
// - availability / authorization state transitions;
// - sync coordinator degradation when FinanceKit (or any provider) is
//   unavailable;
// - provider-neutral mapping onto ``FinancialSnapshotSource``;
// - no-provider and partial-provider cases;
// - copy guard for any new user-facing labels around connection state.

import Foundation
import Testing

@testable import NomadFi

struct FinancialDataProviderArchitectureTests {

    // MARK: - Kind mapping + provenance

    @Test("Provider kinds map onto the existing FinancialSnapshotSource contract")
    func kindsProjectOntoSnapshotSource() {
        #expect(FinancialDataProviderKind.manual.persistedSnapshotSource == .userSnapshot)
        #expect(FinancialDataProviderKind.csvImport.persistedSnapshotSource == .imported)
        #expect(FinancialDataProviderKind.financeKit.persistedSnapshotSource == .financeKit)
        #expect(
            FinancialDataProviderKind.externalAggregator(identifier: "demo")
                .persistedSnapshotSource == .imported
        )
    }

    @Test("Only FinanceKit and external aggregator are entitlement-gated")
    func gatingFlagsMatchProductPolicy() {
        #expect(!FinancialDataProviderKind.manual.isEntitlementGated)
        #expect(!FinancialDataProviderKind.csvImport.isEntitlementGated)
        #expect(FinancialDataProviderKind.financeKit.isEntitlementGated)
        #expect(
            FinancialDataProviderKind.externalAggregator(identifier: "acme")
                .isEntitlementGated
        )
    }

    @Test("logKey is stable and vendor-neutral")
    func logKeysAreStable() {
        #expect(FinancialDataProviderKind.manual.logKey == "manual")
        #expect(FinancialDataProviderKind.csvImport.logKey == "csv_import")
        #expect(FinancialDataProviderKind.financeKit.logKey == "finance_kit")
        #expect(
            FinancialDataProviderKind.externalAggregator(identifier: "acme").logKey
                == "external_aggregator.acme"
        )
        #expect(
            FinancialDataProviderKind.externalAggregator(identifier: "").logKey
                == "external_aggregator"
        )
    }

    // MARK: - Provider-neutral snapshot mapping

    @Test("FinancialAccountSnapshot stamps the matching FinancialSnapshotSource")
    func accountSnapshotCarriesProvenance() {
        let now = Date(timeIntervalSince1970: 1_714_000_000)
        let snap = FinancialAccountSnapshot(
            id: "apple-card-1",
            providerKind: .financeKit,
            displayName: "Apple Card",
            institutionName: "Apple",
            accountType: .creditCard,
            currencyCode: .usd,
            currentBalance: 120,
            creditLimit: 5_000,
            availableCredit: 4_880,
            statementBalance: 100,
            refreshedAt: now
        )
        #expect(snap.persistedSnapshotSource == .financeKit)
        #expect(snap.currentBalance == 120)
        #expect(snap.refreshedAt == now)
    }

    @Test("Currency is required so the app never invents FX context")
    func transactionSnapshotRequiresCurrency() {
        let snap = FinancialTransactionSnapshot(
            id: "t-1",
            providerKind: .csvImport,
            accountID: "acct-1",
            merchantName: "Sample Merchant",
            amount: -25.50,
            currencyCode: .cad,
            date: Date(timeIntervalSince1970: 1_714_000_000),
            category: .food,
            externalTransactionID: "ext-1"
        )
        #expect(snap.currencyCode == .cad)
        #expect(snap.externalTransactionID == "ext-1")
    }

    // MARK: - Availability / authorization invariants

    @Test("ManualFinancialDataProvider is always available and authorized")
    func manualProviderAlwaysAuthorized() async {
        let provider = ManualFinancialDataProvider()
        let availability = await provider.availability()
        let auth = await provider.authorizationStatus()
        #expect(availability == .available)
        #expect(auth == .authorized)
    }

    @Test("CSVImportFinancialDataProvider is always available and authorized")
    func csvProviderAlwaysAuthorized() async {
        let provider = CSVImportFinancialDataProvider()
        let availability = await provider.availability()
        let auth = await provider.authorizationStatus()
        #expect(availability == .available)
        #expect(auth == .authorized)
    }

    @Test("ExternalAggregatorFinancialDataProvider reports integrationNotImplemented")
    func aggregatorPlaceholderUnavailable() async {
        let provider = ExternalAggregatorFinancialDataProvider(identifier: "demo")
        let availability = await provider.availability()
        let auth = await provider.authorizationStatus()
        #expect(availability == .unavailable(reason: .integrationNotImplemented))
        #expect(auth == .unavailable)

        do {
            _ = try await provider.fetchAccountSnapshots()
            Issue.record("Expected aggregator fetch to throw")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.integrationNotImplemented))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Aggregator placeholder throws the integration-not-implemented error on authorization")
    func aggregatorPlaceholderThrowsOnAuthorization() async {
        let provider = ExternalAggregatorFinancialDataProvider()
        do {
            _ = try await provider.requestAuthorization()
            Issue.record("Expected aggregator placeholder to throw")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.integrationNotImplemented))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Coordinator: provider selection + fallback

    @Test("Coordinator surfaces all registered providers in order")
    func coordinatorPreservesProviderOrder() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider(),
            ExternalAggregatorFinancialDataProvider(identifier: "demo")
        ])
        let status = await coordinator.status()
        #expect(status.map(\.kind) == [
            .manual,
            .csvImport,
            .externalAggregator(identifier: "demo")
        ])
    }

    @Test("Coordinator can resolve a provider by kind")
    func coordinatorLooksUpByKind() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider()
        ])
        #expect(coordinator.provider(for: .manual) != nil)
        #expect(coordinator.provider(for: .csvImport) != nil)
        #expect(coordinator.provider(for: .financeKit) == nil)
    }

    // MARK: - Coordinator: sync degradation

    @Test("syncAll degrades gracefully when a provider is unavailable")
    func syncDegradesWhenProviderUnavailable() async {
        let now = Date(timeIntervalSince1970: 1_714_000_000)
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider(),
            ExternalAggregatorFinancialDataProvider(identifier: "demo")
        ])
        let report = await coordinator.syncAll(
            from: now.addingTimeInterval(-86_400 * 30),
            to: now,
            now: now
        )
        #expect(report.degradedGracefully)
        #expect(report.outcomes.count == 3)

        let aggregatorOutcome = report.outcomes.first { $0.providerKind == .externalAggregator(identifier: "demo") }
        #expect(aggregatorOutcome != nil)
        if let outcome = aggregatorOutcome {
            #expect(outcome.result == .skippedUnavailable(.integrationNotImplemented))
        }
    }

    @Test("syncAll treats an authorizationRequired provider as a skip, not a failure")
    func syncSkipsWhenAuthorizationPending() async {
        let now = Date(timeIntervalSince1970: 1_714_000_000)
        let pending = StubProvider(
            kind: .externalAggregator(identifier: "pending"),
            availability: .available,
            authorization: .notDetermined
        )
        let coordinator = FinancialDataSyncCoordinator(providers: [pending])
        let report = await coordinator.syncAll(from: now, to: now, now: now)
        #expect(report.outcomes.count == 1)
        #expect(report.outcomes.first?.result == .skippedAuthorizationRequired)
        #expect(report.degradedGracefully)
    }

    @Test("A provider's thrown error is captured as a failed outcome without stopping the pass")
    func syncCapturesThrowingProviders() async {
        let now = Date(timeIntervalSince1970: 1_714_000_000)
        let throwing = StubProvider(
            kind: .externalAggregator(identifier: "boom"),
            availability: .available,
            authorization: .authorized,
            fetchError: .refreshFailed
        )
        let manual = ManualFinancialDataProvider()
        let coordinator = FinancialDataSyncCoordinator(providers: [manual, throwing])

        let report = await coordinator.syncAll(from: now, to: now, now: now)
        #expect(report.outcomes.count == 2)
        #expect(!report.degradedGracefully)

        let throwingOutcome = report.outcomes.first { $0.providerKind == throwing.kind }
        #expect(throwingOutcome?.result == .failed(.refreshFailed))

        let manualOutcome = report.outcomes.first { $0.providerKind == .manual }
        #expect(manualOutcome?.result == .succeeded)
    }

    @Test("syncAll passes an account snapshot through when a stub provider returns one")
    func syncPassesSnapshotsThrough() async {
        let now = Date(timeIntervalSince1970: 1_714_000_000)
        let stub = StubProvider(
            kind: .externalAggregator(identifier: "test"),
            availability: .available,
            authorization: .authorized,
            accountSnapshots: [
                FinancialAccountSnapshot(
                    id: "stub-1",
                    providerKind: .externalAggregator(identifier: "test"),
                    displayName: "Stub Checking",
                    institutionName: "Stub Bank",
                    accountType: .checking,
                    currencyCode: .usd,
                    currentBalance: 100,
                    refreshedAt: now
                )
            ],
            transactionSnapshots: [
                FinancialTransactionSnapshot(
                    id: "tx-1",
                    providerKind: .externalAggregator(identifier: "test"),
                    accountID: "stub-1",
                    merchantName: "Sample Merchant",
                    amount: -12,
                    currencyCode: .usd,
                    date: now,
                    category: .food
                )
            ]
        )
        let coordinator = FinancialDataSyncCoordinator(providers: [stub])
        let report = await coordinator.syncAll(from: now, to: now, now: now)
        #expect(report.accountSnapshots.count == 1)
        #expect(report.transactionSnapshots.count == 1)
        #expect(report.outcomes.first?.accountCount == 1)
        #expect(report.outcomes.first?.transactionCount == 1)
        #expect(report.outcomes.first?.result == .succeeded)
    }

    // MARK: - No-provider / partial-provider edges

    @Test("syncAll on an empty provider list degrades gracefully with zero outcomes")
    func syncOnEmptyProviderList() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [])
        let report = await coordinator.syncAll(from: .now, to: .now)
        #expect(report.accountSnapshots.isEmpty)
        #expect(report.transactionSnapshots.isEmpty)
        #expect(report.outcomes.isEmpty)
        #expect(report.degradedGracefully)
    }

    @Test("requestAuthorization on an unregistered provider throws unavailable")
    func authorizationThrowsForUnregisteredProvider() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider()
        ])
        do {
            _ = try await coordinator.requestAuthorization(for: .financeKit)
            Issue.record("Expected unavailable error")
        } catch let error as FinancialDataProviderError {
            #expect(error == .providerUnavailable(.integrationNotImplemented))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Availability + connection status

    @Test("ProviderStatus.canSync requires both availability and authorization")
    func canSyncRequiresBothGates() {
        let allGood = FinancialDataSyncCoordinator.ProviderStatus(
            kind: .manual,
            availability: .available,
            authorization: .authorized
        )
        #expect(allGood.canSync)

        let pending = FinancialDataSyncCoordinator.ProviderStatus(
            kind: .financeKit,
            availability: .available,
            authorization: .notDetermined
        )
        #expect(!pending.canSync)

        let unavailable = FinancialDataSyncCoordinator.ProviderStatus(
            kind: .financeKit,
            availability: .unavailable(reason: .notSupportedOnDevice),
            authorization: .authorized
        )
        #expect(!unavailable.canSync)
    }

    @Test("ManualFinancialDataProvider exposes a single connected connection")
    func manualConnectionIsExplicit() async {
        let provider = ManualFinancialDataProvider()
        let connections = await provider.connections()
        #expect(connections.count == 1)
        #expect(connections.first?.providerKind == .manual)
        #expect(connections.first?.status == .connected)
    }

    @Test("Connection degradation reasons round-trip through their log labels")
    func degradationReasonsHaveStableLabels() {
        #expect(
            FinancialDataConnectionStatus.DegradationReason.partialSync.logLabel == "partial_sync"
        )
        #expect(
            FinancialDataConnectionStatus.DegradationReason.refreshFailed.logLabel == "refresh_failed"
        )
    }

    // MARK: - Copy guard

    @Test("Display labels never claim coverage NomadFi does not have")
    func copyGuardOnDisplayLabels() {
        let banned = [
            "all banks",
            "every account",
            "universal",
            "guaranteed",
            "best card"
        ]
        let kinds: [FinancialDataProviderKind] = [
            .manual,
            .csvImport,
            .financeKit,
            .externalAggregator(identifier: "demo")
        ]
        for kind in kinds {
            let label = kind.displayLabel.lowercased()
            for phrase in banned {
                #expect(
                    !label.contains(phrase),
                    "Provider display label should not contain \"\(phrase)\": \(label)"
                )
            }
        }
    }

    @Test("Availability reason log labels stay log-safe and vendor-neutral")
    func availabilityLogLabelsAreLogSafe() {
        let reasons: [FinancialDataProviderAvailability.UnavailableReason] = [
            .notSupportedOnPlatform,
            .notSupportedOnDevice,
            .entitlementNotProvisioned,
            .integrationNotImplemented
        ]
        for reason in reasons {
            let label = reason.logLabel
            #expect(!label.contains(" "))
            #expect(label == label.lowercased())
        }
    }
}

// MARK: - Test double

/// Minimal in-memory provider used by the coordinator tests. Kept
/// inside the test file so the production target never ships a fake
/// implementation.
private struct StubProvider: FinancialDataProvider {
    let kind: FinancialDataProviderKind
    let availabilityState: FinancialDataProviderAvailability
    let authorization: FinancialDataAuthorizationStatus
    let accountSnapshots: [FinancialAccountSnapshot]
    let transactionSnapshots: [FinancialTransactionSnapshot]
    let fetchError: FinancialDataProviderError?

    init(
        kind: FinancialDataProviderKind,
        availability: FinancialDataProviderAvailability,
        authorization: FinancialDataAuthorizationStatus,
        accountSnapshots: [FinancialAccountSnapshot] = [],
        transactionSnapshots: [FinancialTransactionSnapshot] = [],
        fetchError: FinancialDataProviderError? = nil
    ) {
        self.kind = kind
        self.availabilityState = availability
        self.authorization = authorization
        self.accountSnapshots = accountSnapshots
        self.transactionSnapshots = transactionSnapshots
        self.fetchError = fetchError
    }

    func availability() async -> FinancialDataProviderAvailability { availabilityState }
    func authorizationStatus() async -> FinancialDataAuthorizationStatus { authorization }
    func requestAuthorization() async throws -> FinancialDataAuthorizationStatus { authorization }
    func connections() async -> [FinancialDataConnection] { [] }

    func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] {
        if let fetchError { throw fetchError }
        return accountSnapshots
    }

    func fetchTransactionSnapshots(
        accountID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [FinancialTransactionSnapshot] {
        if let fetchError { throw fetchError }
        return transactionSnapshots.filter { $0.accountID == accountID }
    }
}
