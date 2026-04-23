// FinancialConnectionsViewModel.swift
// NomadFi
//
// Backs the Settings → Financial Setup → Financial Connections page.
// Reads the provider coordinator's availability / authorization /
// connection state, runs the FinanceKit authorization prompt in
// response to an explicit user action, and drives an explicit Sync
// Now flow that reconciles the report into SwiftData through
// ``FinancialDataReconciler``.
//
// @Observable + @MainActor, per the project's Swift 6.2 / strict
// concurrency house rules. The VM never hops off the main actor;
// long-running coordinator work happens inside explicit async calls.

import Foundation
import OSLog
import SwiftData

/// View model for ``FinancialConnectionsSettingsView``.
@MainActor
@Observable
final class FinancialConnectionsViewModel {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "FinancialConnections"
    )

    /// Rows rendered on the page, one per registered provider.
    /// Computed from the last coordinator status pass.
    private(set) var rows: [Row] = []

    /// Set while an authorization prompt or sync is in flight. The
    /// view disables actions and surfaces a calm progress row.
    private(set) var isWorking: Bool = false

    /// Last reconciliation summary — populated after Sync Now. Nil
    /// until the user has run at least one sync.
    private(set) var lastReconciliation: FinancialDataReconciliationResult?

    /// Human-readable, localised summary of the last sync. Nil when
    /// no sync has run yet; calm factual copy otherwise.
    private(set) var lastSyncSummary: LocalizedStringResource?

    private let coordinator: FinancialDataSyncCoordinator
    private let homeCurrency: CurrencyCode

    init(
        coordinator: FinancialDataSyncCoordinator = .live(),
        homeCurrency: CurrencyCode = .usd
    ) {
        self.coordinator = coordinator
        self.homeCurrency = homeCurrency
    }

    // MARK: - Lifecycle

    /// Loads the current provider status. Safe to call repeatedly —
    /// the coordinator's status call is cheap and never prompts the
    /// user.
    func refresh() async {
        let statuses = await coordinator.status()
        let connections = await coordinator.connections()
        rows = statuses.map { status in
            Row(
                id: status.kind.logKey,
                kind: status.kind,
                availability: status.availability,
                authorization: status.authorization,
                connection: connections.first { $0.providerKind == status.kind }
            )
        }
    }

    // MARK: - Actions

    /// Runs FinanceKit's official authorization prompt. Only call
    /// in response to an explicit user action — FinanceKit surfaces
    /// a system sheet that is part of the managed entitlement flow.
    func requestAuthorization(for kind: FinancialDataProviderKind) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await coordinator.requestAuthorization(for: kind)
        } catch {
            Self.logger.error(
                "Authorization request failed for \(kind.logKey, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        await refresh()
    }

    /// Explicit Sync Now: runs every provider the coordinator knows
    /// about, reconciles the resulting report into the SwiftData
    /// store, and refreshes the rows so the UI reflects the new
    /// state. Honest degradation is preserved — a single failing
    /// provider does not prevent others from contributing.
    func syncNow(
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext,
        existingAccounts: [Account],
        existingTransactions: [Transaction],
        now: Date = .now
    ) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let report = await coordinator.syncAll(
            from: startDate,
            to: endDate,
            now: now
        )

        let result = FinancialDataReconciler.apply(
            report,
            into: modelContext,
            existingAccounts: existingAccounts,
            existingTransactions: existingTransactions,
            homeCurrency: homeCurrency,
            now: now
        )
        lastReconciliation = result
        lastSyncSummary = Self.summary(for: result)
        await refresh()
    }

    // MARK: - Derived UI state

    /// Row projection for the list. Includes a precomputed UI state
    /// so the view body stays short and the tests can assert against
    /// the exact labels.
    struct Row: Identifiable, Sendable, Equatable {
        let id: String
        let kind: FinancialDataProviderKind
        let availability: FinancialDataProviderAvailability
        let authorization: FinancialDataAuthorizationStatus
        let connection: FinancialDataConnection?

        /// Localised title for the row. Mirrors the provider kind's
        /// honest display label — never a marketing claim.
        var title: LocalizedStringResource {
            switch kind {
            case .manual: "Manual entry"
            case .csvImport: "CSV import"
            case .financeKit: "Apple FinanceKit"
            case .externalAggregator: "External aggregator"
            }
        }

        /// Calm, factual status line. Copy is pinned by tests so the
        /// page never starts claiming coverage NomadFi does not have.
        var statusLabel: LocalizedStringResource {
            switch availability {
            case .unavailable(let reason):
                switch reason {
                case .notSupportedOnPlatform: "Not supported on this platform"
                case .notSupportedOnDevice: "Not available on this device"
                case .entitlementNotProvisioned: "Available on supported devices"
                case .integrationNotImplemented: "Not enabled in this build"
                }
            case .availableNoConnections, .available:
                switch authorization {
                case .authorized: "Connected"
                case .denied: "Authorization required"
                case .notDetermined: "Authorization required"
                case .unavailable: "Not available on this device"
                }
            }
        }

        /// Whether the "Authorize" action should be offered. Only
        /// offered when the provider is available and the authorization
        /// state can move through a consent prompt.
        var canRequestAuthorization: Bool {
            guard availability.isAvailable else { return false }
            switch authorization {
            case .notDetermined, .denied: return true
            case .authorized, .unavailable: return false
            }
        }

        /// Calm last-sync detail, only populated when the coordinator
        /// reports a successful sync for this provider.
        var lastSyncDetail: LocalizedStringResource? {
            guard let connection, let lastSync = connection.lastSyncAt else {
                return nil
            }
            return "Last synced \(lastSync.formatted(.relative(presentation: .named)))"
        }
    }

    // MARK: - Copy

    private static func summary(
        for result: FinancialDataReconciliationResult
    ) -> LocalizedStringResource {
        if result.isNoOp {
            return "No changes from the last sync."
        }
        return "Synced. \(result.createdAccounts) new, \(result.updatedAccounts) updated, \(result.insertedTransactions) transactions imported."
    }
}
