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
//
// Phase 5C additions:
// - Tracks per-provider sync outcomes so the UI can honestly say
//   "Authorized, no eligible accounts" when FinanceKit returns zero
//   rows under a valid authorization.
// - Tracks the last successful sync timestamp per provider and
//   renders it as an absolute (static) date string, matching the
//   repo rule "static date formatting, not relative".

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
    /// Computed from the last coordinator status pass plus the last
    /// sync's per-provider outcomes.
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

    /// Per-provider outcome from the most recent sync pass, keyed by
    /// `FinancialDataProviderKind.logKey`. Populated by `syncNow`.
    private var lastOutcomesByKey: [String: SyncOutcome] = [:]

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
                connection: connections.first { $0.providerKind == status.kind },
                lastOutcome: lastOutcomesByKey[status.kind.logKey]
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

        for outcome in report.outcomes {
            lastOutcomesByKey[outcome.providerKind.logKey] = SyncOutcome(
                accountCount: outcome.accountCount,
                transactionCount: outcome.transactionCount,
                result: outcome.result,
                completedAt: report.completedAt
            )
        }
        await refresh()
    }

    // MARK: - Derived UI state

    /// Per-provider sync outcome retained on the VM. Narrow subset of
    /// ``FinancialDataSyncReport/ProviderOutcome`` so the Row stays
    /// `Sendable` and `Equatable` without hauling framework-facing
    /// associated values through the `Equatable` derivation.
    struct SyncOutcome: Sendable, Equatable {
        let accountCount: Int
        let transactionCount: Int
        let result: FinancialDataSyncReport.ProviderOutcome.Result
        let completedAt: Date
    }

    /// Row projection for the list. Includes a precomputed UI state
    /// so the view body stays short and the tests can assert against
    /// the exact labels.
    struct Row: Identifiable, Sendable, Equatable {
        let id: String
        let kind: FinancialDataProviderKind
        let availability: FinancialDataProviderAvailability
        let authorization: FinancialDataAuthorizationStatus
        let connection: FinancialDataConnection?
        let lastOutcome: SyncOutcome?

        init(
            id: String,
            kind: FinancialDataProviderKind,
            availability: FinancialDataProviderAvailability,
            authorization: FinancialDataAuthorizationStatus,
            connection: FinancialDataConnection?,
            lastOutcome: SyncOutcome? = nil
        ) {
            self.id = id
            self.kind = kind
            self.availability = availability
            self.authorization = authorization
            self.connection = connection
            self.lastOutcome = lastOutcome
        }

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

        /// True when the provider succeeded in its last sync but
        /// returned zero account snapshots under a valid
        /// authorization — user is authorized, but Apple has no
        /// eligible accounts to expose (no Apple Card / Apple Cash /
        /// Apple Savings in the US; no supported open-banking
        /// institution in the UK).
        var isAuthorizedWithZeroAccounts: Bool {
            guard availability.isAvailable, authorization == .authorized else {
                return false
            }
            guard let lastOutcome else { return false }
            switch lastOutcome.result {
            case .succeeded: return lastOutcome.accountCount == 0
            default: return false
            }
        }

        /// Calm, factual status line. Copy is pinned by tests so the
        /// page never starts claiming coverage NomadFi does not have.
        var statusLabel: LocalizedStringResource {
            switch availability {
            case .unavailable(let reason):
                switch reason {
                case .notSupportedOnPlatform: return "Not supported on this platform"
                case .notSupportedOnDevice: return "Not available on this device"
                case .entitlementNotProvisioned: return "Available on supported devices"
                case .integrationNotImplemented: return "Not enabled in this build"
                }
            case .availableNoConnections, .available:
                switch authorization {
                case .authorized:
                    if isAuthorizedWithZeroAccounts {
                        return "Authorized — no eligible accounts found"
                    }
                    return "Connected"
                case .denied: return "Authorization required"
                case .notDetermined: return "Authorization required"
                case .unavailable: return "Available on supported devices"
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

        /// Calm last-sync detail. Uses a static absolute-date format
        /// per repo UI rules ("static date formatting, not relative
        /// date formatting"). Returns `nil` when no successful sync
        /// has happened for this provider.
        var lastSyncDetail: LocalizedStringResource? {
            guard let completedAt = lastSuccessfulSyncAt else { return nil }
            let formatted = completedAt.formatted(
                date: .abbreviated,
                time: .shortened
            )
            return "Last synced \(formatted)"
        }

        /// Returns the absolute timestamp of the last *successful*
        /// sync for this provider. Skipped and failed outcomes don't
        /// count as a last-successful-sync — they'd otherwise
        /// mislead the user into thinking the provider refreshed.
        var lastSuccessfulSyncAt: Date? {
            guard let lastOutcome else { return nil }
            switch lastOutcome.result {
            case .succeeded: return lastOutcome.completedAt
            default: return nil
            }
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
