// FinancialDataSyncCoordinator.swift
// NomadFi
//
// Coordinates the set of ``FinancialDataProvider`` instances so the
// rest of the app never has to care which upstream produced a given
// snapshot. The coordinator:
// - reports availability and authorization state per-provider;
// - requests authorization on a named provider in response to explicit
//   user action;
// - runs a sync pass across every provider and returns a
//   provider-neutral ``FinancialDataSyncReport``;
// - degrades gracefully — a single failing provider never prevents
//   another provider from contributing data.
//
// The coordinator never writes to SwiftData on its own. It hands the
// merged snapshots back; callers apply them through the existing
// account / transaction persistence paths so engines (Credit Timing,
// Purchase Decision, Dashboard) keep getting their data from the same
// authoritative store they do today.

import Foundation
import OSLog

/// Fan-out / fan-in point for every ``FinancialDataProvider`` the app
/// knows about. Safe to call from any actor; the coordinator is a
/// reference type so UI can hold a single instance and query it
/// repeatedly, but it holds no mutable user-facing state — the truth
/// lives in the SwiftData store.
final class FinancialDataSyncCoordinator: Sendable {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialData.Coordinator"
    )

    let providers: [any FinancialDataProvider]

    /// - Parameter providers: Ordered list of providers the coordinator
    ///   should consult. Order drives deterministic outcome ordering
    ///   in ``FinancialDataSyncReport`` and lets the caller express
    ///   preference (e.g. put manual first so UI lists it first).
    init(providers: [any FinancialDataProvider]) {
        self.providers = providers
    }

    // MARK: - Introspection

    /// Provider with the matching kind, if registered. Used by the
    /// authorization flow and UI to dispatch to a single upstream.
    func provider(for kind: FinancialDataProviderKind) -> (any FinancialDataProvider)? {
        providers.first { $0.kind == kind }
    }

    /// Cheap availability + authorization snapshot for every
    /// registered provider. Never prompts the user.
    func status() async -> [ProviderStatus] {
        var result: [ProviderStatus] = []
        result.reserveCapacity(providers.count)
        for provider in providers {
            let availability = await provider.availability()
            let authorization = await provider.authorizationStatus()
            result.append(
                ProviderStatus(
                    kind: provider.kind,
                    availability: availability,
                    authorization: authorization
                )
            )
        }
        return result
    }

    /// Flatten the per-provider connection lists. UI uses this to
    /// render "connected sources" in Settings without caring which
    /// provider owns which row.
    func connections() async -> [FinancialDataConnection] {
        var all: [FinancialDataConnection] = []
        for provider in providers {
            let connections = await provider.connections()
            all.append(contentsOf: connections)
        }
        return all
    }

    // MARK: - Authorization

    /// Prompts for consent on a named provider. Only call in response
    /// to an explicit user action. Throws
    /// ``FinancialDataProviderError/providerUnavailable(_:)`` when the
    /// provider is not registered or not available on this device.
    func requestAuthorization(
        for kind: FinancialDataProviderKind
    ) async throws -> FinancialDataAuthorizationStatus {
        guard let provider = provider(for: kind) else {
            throw FinancialDataProviderError.providerUnavailable(.integrationNotImplemented)
        }
        switch await provider.availability() {
        case .unavailable(let reason):
            throw FinancialDataProviderError.providerUnavailable(reason)
        case .available, .availableNoConnections:
            return try await provider.requestAuthorization()
        }
    }

    // MARK: - Sync

    /// Run every provider in order. Each provider's failure or
    /// unavailability is captured as an outcome; the overall sync
    /// never throws. Callers that need to distinguish partial success
    /// from total failure should consult
    /// ``FinancialDataSyncReport/degradedGracefully``.
    func syncAll(
        from startDate: Date,
        to endDate: Date,
        now: Date = .now
    ) async -> FinancialDataSyncReport {
        var accountSnapshots: [FinancialAccountSnapshot] = []
        var transactionSnapshots: [FinancialTransactionSnapshot] = []
        var outcomes: [FinancialDataSyncReport.ProviderOutcome] = []

        for provider in providers {
            let outcome = await syncProvider(
                provider,
                from: startDate,
                to: endDate,
                accountSnapshots: &accountSnapshots,
                transactionSnapshots: &transactionSnapshots
            )
            outcomes.append(outcome)
        }

        return FinancialDataSyncReport(
            accountSnapshots: accountSnapshots,
            transactionSnapshots: transactionSnapshots,
            outcomes: outcomes,
            completedAt: now
        )
    }

    private func syncProvider(
        _ provider: any FinancialDataProvider,
        from startDate: Date,
        to endDate: Date,
        accountSnapshots: inout [FinancialAccountSnapshot],
        transactionSnapshots: inout [FinancialTransactionSnapshot]
    ) async -> FinancialDataSyncReport.ProviderOutcome {
        switch await provider.availability() {
        case .unavailable(let reason):
            Self.logger.info(
                "Provider \(provider.kind.logKey, privacy: .public) unavailable: \(reason.logLabel, privacy: .public)"
            )
            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .skippedUnavailable(reason),
                accountCount: 0,
                transactionCount: 0
            )
        case .available, .availableNoConnections:
            break
        }

        switch await provider.authorizationStatus() {
        case .authorized: break
        case .notDetermined, .denied:
            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .skippedAuthorizationRequired,
                accountCount: 0,
                transactionCount: 0
            )
        case .unavailable:
            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .skippedUnavailable(.notSupportedOnDevice),
                accountCount: 0,
                transactionCount: 0
            )
        }

        do {
            let providerAccounts = try await provider.fetchAccountSnapshots()
            accountSnapshots.append(contentsOf: providerAccounts)

            var providerTransactionCount = 0
            for account in providerAccounts {
                let rows = try await provider.fetchTransactionSnapshots(
                    accountID: account.id,
                    from: startDate,
                    to: endDate
                )
                providerTransactionCount += rows.count
                transactionSnapshots.append(contentsOf: rows)
            }

            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .succeeded,
                accountCount: providerAccounts.count,
                transactionCount: providerTransactionCount
            )
        } catch let error as FinancialDataProviderError {
            Self.logger.error(
                "Provider \(provider.kind.logKey, privacy: .public) failed: \(String(describing: error), privacy: .public)"
            )
            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .failed(error),
                accountCount: 0,
                transactionCount: 0
            )
        } catch {
            Self.logger.error(
                "Provider \(provider.kind.logKey, privacy: .public) threw unexpected error: \(error.localizedDescription, privacy: .public)"
            )
            return FinancialDataSyncReport.ProviderOutcome(
                providerKind: provider.kind,
                result: .failed(.refreshFailed),
                accountCount: 0,
                transactionCount: 0
            )
        }
    }

    /// Called by the caller after a successful reconciliation. Forwards
    /// to every provider's ``FinancialDataProvider/finalizeSync()``
    /// hook. Providers that don't track state (manual / CSV /
    /// FinanceKit today) no-op via the protocol extension; stateful
    /// providers (the Plaid sandbox adapter) persist their advancing
    /// cursor here so a reconciler failure never strands rows.
    func finalizeAfterCommit() async {
        for provider in providers {
            await provider.finalizeSync()
        }
    }

    // MARK: - Preset factory

    /// Production provider stack: manual + CSV + FinanceKit + the
    /// Plaid *sandbox* adapter. The Plaid adapter stays in the
    /// `integrationNotImplemented` state until a developer configures
    /// a local broker URL in the Keychain — which is how a shipping
    /// build behaves today. Configuration is explicitly scoped to
    /// Phase 5D's bounded sandbox proof (see
    /// `tools/plaid-sandbox-broker/` and
    /// `docs/research/PlaidSandboxProof.md`).
    @MainActor
    static func live() -> FinancialDataSyncCoordinator {
        var providers: [any FinancialDataProvider] = [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider(),
            FinanceKitFinancialDataProvider(),
        ]
        #if DEBUG
            // A developer validation path against a local sandbox
            // broker; never registered in builds people install.
            providers.append(PlaidSandboxFinancialDataProvider())
        #endif
        return FinancialDataSyncCoordinator(providers: providers)
    }

    /// Preview / Xcode-canvas provider stack. Same shape as the live
    /// stack minus FinanceKit (which always reports unavailable off a
    /// real device).
    @MainActor
    static func preview() -> FinancialDataSyncCoordinator {
        FinancialDataSyncCoordinator(providers: [
            ManualFinancialDataProvider(),
            CSVImportFinancialDataProvider()
        ])
    }
}

// MARK: - Supporting types

extension FinancialDataSyncCoordinator {

    /// Value projection of one provider's current availability /
    /// authorization state. Consumed by Settings UI and tests.
    struct ProviderStatus: Sendable, Equatable, Identifiable {
        let kind: FinancialDataProviderKind
        let availability: FinancialDataProviderAvailability
        let authorization: FinancialDataAuthorizationStatus

        var id: String { kind.logKey }

        /// True when the coordinator can ask this provider to run a
        /// data fetch right now. UI gates "sync" actions on this.
        var canSync: Bool {
            availability.isAvailable && authorization == .authorized
        }
    }
}
