// FinancialDataSyncReport.swift
// NomadFi
//
// Result of a single coordinator sync pass. Captures which providers
// contributed, which degraded, and which snapshots the caller needs
// to reconcile into SwiftData. The coordinator never writes to the
// store directly — it hands the report back; callers apply it using
// the existing ``Account`` / ``Transaction`` persistence paths.

import Foundation

/// Summary of one coordinator sync. Value-typed so tests can assert
/// on every branch without any IO.
struct FinancialDataSyncReport: Sendable, Equatable {

    /// Snapshots the caller should merge into SwiftData.
    let accountSnapshots: [FinancialAccountSnapshot]
    let transactionSnapshots: [FinancialTransactionSnapshot]

    /// Per-provider outcomes, keyed by log-safe identifier. Order is
    /// deterministic so UI can render a stable list.
    let outcomes: [ProviderOutcome]

    /// When the coordinator completed the pass.
    let completedAt: Date

    init(
        accountSnapshots: [FinancialAccountSnapshot] = [],
        transactionSnapshots: [FinancialTransactionSnapshot] = [],
        outcomes: [ProviderOutcome] = [],
        completedAt: Date = .now
    ) {
        self.accountSnapshots = accountSnapshots
        self.transactionSnapshots = transactionSnapshots
        self.outcomes = outcomes
        self.completedAt = completedAt
    }

    /// Outcome for a single provider within one sync pass. The
    /// coordinator builds one of these for every provider it attempted
    /// to query, even if the provider was unavailable — surfacing
    /// graceful degradation explicitly rather than hiding it.
    struct ProviderOutcome: Sendable, Equatable, Identifiable {

        let providerKind: FinancialDataProviderKind
        let result: Result
        let accountCount: Int
        let transactionCount: Int

        var id: String { providerKind.logKey }

        enum Result: Sendable, Equatable {

            /// Provider ran, returned data (possibly zero rows) and
            /// did not degrade.
            case succeeded

            /// Provider skipped because it is unavailable on this
            /// device / region / entitlement state.
            case skippedUnavailable(FinancialDataProviderAvailability.UnavailableReason)

            /// Provider is available but needs consent.
            case skippedAuthorizationRequired

            /// Provider errored mid-sync. Kept narrow on purpose — UI
            /// maps each case to honest copy.
            case failed(FinancialDataProviderError)

            var logLabel: String {
                switch self {
                case .succeeded: "succeeded"
                case .skippedUnavailable(let reason): "skipped_unavailable.\(reason.logLabel)"
                case .skippedAuthorizationRequired: "skipped_authorization_required"
                case .failed: "failed"
                }
            }
        }
    }

    /// True when every provider the coordinator queried either ran
    /// successfully or skipped for a known reason. UI uses this to
    /// decide whether to show a retry affordance.
    var degradedGracefully: Bool {
        outcomes.allSatisfy { outcome in
            switch outcome.result {
            case .succeeded, .skippedUnavailable, .skippedAuthorizationRequired: true
            case .failed: false
            }
        }
    }
}
