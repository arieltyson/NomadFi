// FinancialConnectionsViewModelTests.swift
// NomadFi
//
// Phase 5B coverage for ``FinancialConnectionsViewModel`` and the
// Settings page it powers. Focuses on status/connection projection,
// calm factual copy, and the absence of marketing claims.
//
// The coordinator is constructed from an in-test stub provider so
// availability / authorization transitions can be exercised without
// touching the FinanceKit framework.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct FinancialConnectionsViewModelTests {

    // MARK: - Stub provider

    private struct StubProvider: FinancialDataProvider {
        let kind: FinancialDataProviderKind
        let availabilityState: FinancialDataProviderAvailability
        let authorization: FinancialDataAuthorizationStatus
        let connectionsList: [FinancialDataConnection]

        init(
            kind: FinancialDataProviderKind,
            availability: FinancialDataProviderAvailability,
            authorization: FinancialDataAuthorizationStatus,
            connections: [FinancialDataConnection] = []
        ) {
            self.kind = kind
            self.availabilityState = availability
            self.authorization = authorization
            self.connectionsList = connections
        }

        func availability() async -> FinancialDataProviderAvailability { availabilityState }
        func authorizationStatus() async -> FinancialDataAuthorizationStatus { authorization }
        func requestAuthorization() async throws -> FinancialDataAuthorizationStatus { authorization }
        func connections() async -> [FinancialDataConnection] { connectionsList }
        func fetchAccountSnapshots() async throws -> [FinancialAccountSnapshot] { [] }
        func fetchTransactionSnapshots(
            accountID: String,
            from startDate: Date,
            to endDate: Date
        ) async throws -> [FinancialTransactionSnapshot] { [] }
    }

    // MARK: - Rows

    @Test("refresh() produces one row per provider in coordinator order")
    func refreshProducesOneRowPerProvider() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider(),
            StubProvider(
                kind: .financeKit,
                availability: .unavailable(reason: .notSupportedOnDevice),
                authorization: .unavailable
            ),
            ExternalAggregatorFinancialDataProvider(identifier: "demo")
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()
        #expect(viewModel.rows.map(\.kind) == [
            .manual,
            .csvImport,
            .financeKit,
            .externalAggregator(identifier: "demo")
        ])
    }

    @Test("FinanceKit unavailable (simulator / unsupported device) shows 'Not available on this device'")
    func financeKitUnavailableShowsCalmLabel() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            StubProvider(
                kind: .financeKit,
                availability: .unavailable(reason: .notSupportedOnDevice),
                authorization: .unavailable
            )
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()

        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Not available on this device")
            #expect(!row.canRequestAuthorization)
        }
    }

    @Test("FinanceKit entitlement-not-provisioned stays calm and available-ish")
    func financeKitEntitlementPendingShowsCalmLabel() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            StubProvider(
                kind: .financeKit,
                availability: .unavailable(reason: .entitlementNotProvisioned),
                authorization: .unavailable
            )
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()

        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Available on supported devices")
        }
    }

    @Test("FinanceKit available but not determined offers Authorize and says 'Authorization required'")
    func financeKitNotDeterminedOffersAuthorize() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            StubProvider(
                kind: .financeKit,
                availability: .available,
                authorization: .notDetermined
            )
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()

        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Authorization required")
            #expect(row.canRequestAuthorization)
        }
    }

    @Test("FinanceKit denied does NOT re-offer Authorize — it'd loop the user through a rejected prompt")
    func financeKitDeniedOffersAuthorize() async {
        // Note: we DO offer "Authorize" on denied so the user can
        // try again after granting consent in Settings.app. Apple's
        // managed flow will resurface the consent panel when the
        // state changes outside the app.
        let coordinator = FinancialDataSyncCoordinator(providers: [
            StubProvider(
                kind: .financeKit,
                availability: .available,
                authorization: .denied
            )
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()

        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Authorization required")
            #expect(row.canRequestAuthorization)
        }
    }

    @Test("External aggregator placeholder is honest — 'Not enabled in this build'")
    func externalAggregatorHonestCopy() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ExternalAggregatorFinancialDataProvider(identifier: "demo")
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()
        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Not enabled in this build")
            #expect(!row.canRequestAuthorization)
        }
    }

    @Test("Manual provider reports 'Connected' without a consent prompt")
    func manualProviderReportsConnected() async {
        let viewModel = FinancialConnectionsViewModel(coordinator: FinancialDataSyncCoordinator(
            providers: [ManualFinancialDataProvider()]
        ))
        await viewModel.refresh()
        #expect(viewModel.rows.count == 1)
        if let row = viewModel.rows.first {
            #expect(localizedEnglish(row.statusLabel) == "Connected")
            #expect(!row.canRequestAuthorization)
        }
    }

    // MARK: - Copy guard

    @Test("Status labels across every state never contain forbidden marketing phrases")
    func copyGuardAcrossStates() async {
        let coordinator = FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider(),
            StubProvider(
                kind: .financeKit,
                availability: .available,
                authorization: .authorized
            ),
            StubProvider(
                kind: .financeKit,
                availability: .available,
                authorization: .notDetermined
            ),
            StubProvider(
                kind: .financeKit,
                availability: .unavailable(reason: .notSupportedOnDevice),
                authorization: .unavailable
            ),
            ExternalAggregatorFinancialDataProvider(identifier: "demo")
        ])
        let viewModel = FinancialConnectionsViewModel(coordinator: coordinator)
        await viewModel.refresh()

        let forbidden = [
            "all your banks",
            "all your cards",
            "instant sync everywhere",
            "automatic for every institution",
            "apple sees your data",
            "connected to every account"
        ]
        for row in viewModel.rows {
            let status = localizedEnglish(row.statusLabel).lowercased()
            let title = localizedEnglish(row.title).lowercased()
            for phrase in forbidden {
                #expect(
                    !status.contains(phrase),
                    "Forbidden phrase in status: \(phrase) (row: \(status))"
                )
                #expect(
                    !title.contains(phrase),
                    "Forbidden phrase in title: \(phrase)"
                )
            }
        }
    }

    // MARK: - Derived helpers

    @Test("canRequestAuthorization never offers the action for unavailable providers")
    func canRequestAuthorizationFalseWhenUnavailable() {
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .unavailable(reason: .notSupportedOnDevice),
            authorization: .notDetermined,
            connection: nil
        )
        #expect(!row.canRequestAuthorization)
    }

    // MARK: - Phase 5C — authorized-no-accounts state

    @Test("Authorized FinanceKit with zero accounts under a succeeded sync reads as 'no eligible accounts'")
    func authorizedWithZeroAccountsSurfacesHonestCopy() {
        let outcome = FinancialConnectionsViewModel.SyncOutcome(
            accountCount: 0,
            transactionCount: 0,
            result: .succeeded,
            completedAt: Date(timeIntervalSince1970: 1_714_000_000)
        )
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .available,
            authorization: .authorized,
            connection: nil,
            lastOutcome: outcome
        )
        #expect(row.isAuthorizedWithZeroAccounts)
        #expect(localizedEnglish(row.statusLabel) == "Authorized — no eligible accounts found")
        #expect(!row.canRequestAuthorization)
    }

    @Test("Authorized FinanceKit with accounts reads 'Connected', not 'no eligible accounts'")
    func authorizedWithAccountsStaysConnected() {
        let outcome = FinancialConnectionsViewModel.SyncOutcome(
            accountCount: 2,
            transactionCount: 5,
            result: .succeeded,
            completedAt: Date(timeIntervalSince1970: 1_714_000_000)
        )
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .available,
            authorization: .authorized,
            connection: nil,
            lastOutcome: outcome
        )
        #expect(!row.isAuthorizedWithZeroAccounts)
        #expect(localizedEnglish(row.statusLabel) == "Connected")
    }

    @Test("A failed-sync outcome does not masquerade as 'no eligible accounts'")
    func failedSyncDoesNotTriggerZeroAccountsCopy() {
        let outcome = FinancialConnectionsViewModel.SyncOutcome(
            accountCount: 0,
            transactionCount: 0,
            result: .failed(.refreshFailed),
            completedAt: Date(timeIntervalSince1970: 1_714_000_000)
        )
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .available,
            authorization: .authorized,
            connection: nil,
            lastOutcome: outcome
        )
        #expect(!row.isAuthorizedWithZeroAccounts)
        #expect(localizedEnglish(row.statusLabel) == "Connected")
    }

    // MARK: - Phase 5C — static date formatting

    @Test("Last-sync detail renders an absolute date, never a relative phrasing")
    func lastSyncDetailIsStaticDateFormatting() {
        // Fixed reference date far enough in the past that any
        // relative formatter would produce "1 year ago" or similar.
        let completedAt = Date(timeIntervalSince1970: 1_650_000_000)
        let outcome = FinancialConnectionsViewModel.SyncOutcome(
            accountCount: 1,
            transactionCount: 3,
            result: .succeeded,
            completedAt: completedAt
        )
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .available,
            authorization: .authorized,
            connection: nil,
            lastOutcome: outcome
        )
        guard let detail = row.lastSyncDetail else {
            Issue.record("Expected a last-sync detail label for a succeeded sync")
            return
        }
        let text = localizedEnglish(detail).lowercased()
        let forbiddenRelative = [
            " ago", "yesterday", "tomorrow", "last week", "in a year", "minutes ago",
            "hours ago", "seconds ago"
        ]
        for phrase in forbiddenRelative {
            #expect(
                !text.contains(phrase),
                "Last-sync detail leaked relative formatting: \"\(phrase)\" in \(text)"
            )
        }
        // Static format: starts with "Last synced " and includes
        // the abbreviated date (year present).
        #expect(text.hasPrefix("last synced "))
        #expect(text.contains("2022"))
    }

    @Test("A skipped / failed outcome produces no last-sync label")
    func failedOutcomeHidesLastSyncDetail() {
        let outcome = FinancialConnectionsViewModel.SyncOutcome(
            accountCount: 0,
            transactionCount: 0,
            result: .skippedAuthorizationRequired,
            completedAt: Date(timeIntervalSince1970: 1_714_000_000)
        )
        let row = FinancialConnectionsViewModel.Row(
            id: "finance_kit",
            kind: .financeKit,
            availability: .available,
            authorization: .authorized,
            connection: nil,
            lastOutcome: outcome
        )
        #expect(row.lastSyncDetail == nil)
    }

    // MARK: - Helpers

    /// Resolves a `LocalizedStringResource` through the bundle's
    /// English strings so tests can assert on human copy deterministically.
    private func localizedEnglish(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
}
