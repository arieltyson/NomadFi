// FinancialDataConnection.swift
// NomadFi
//
// Describes a single user-consented link to a ``FinancialDataProvider``.
// A connection is the product's vocabulary for "we have permission to
// read from this source right now", independent of whether any
// individual account or transaction has been pulled yet.
//
// The model is provider-neutral on purpose:
// - Manual and CSV connections are implicit and always present.
// - FinanceKit connections reflect the on-device authorization state.
// - External-aggregator connections, once a provider lands, can carry
//   an opaque institution identifier without leaking vendor-specific
//   types into the core domain model.

import Foundation

/// A single live link between NomadFi and an upstream data source.
///
/// Connections are value types. They are cheap to project from the
/// coordinator's state and are *not* persisted to SwiftData today —
/// the authoritative state for manual/CSV lives on ``Account`` /
/// ``Transaction`` rows, and the FinanceKit / aggregator state is
/// re-derived at query time. This keeps the schema free of vendor
/// churn.
struct FinancialDataConnection: Sendable, Equatable, Identifiable {

    let id: String
    let providerKind: FinancialDataProviderKind
    let displayName: String
    let institutionIdentifier: String?
    let status: FinancialDataConnectionStatus
    let connectedAt: Date?
    let lastSyncAt: Date?

    init(
        id: String,
        providerKind: FinancialDataProviderKind,
        displayName: String,
        institutionIdentifier: String? = nil,
        status: FinancialDataConnectionStatus,
        connectedAt: Date? = nil,
        lastSyncAt: Date? = nil
    ) {
        self.id = id
        self.providerKind = providerKind
        self.displayName = displayName
        self.institutionIdentifier = institutionIdentifier
        self.status = status
        self.connectedAt = connectedAt
        self.lastSyncAt = lastSyncAt
    }
}

/// Live state of a ``FinancialDataConnection``. Drives UI copy,
/// coordinator fallback logic, and freshness labelling. Always treated
/// as a point-in-time read — the coordinator refreshes it on demand.
enum FinancialDataConnectionStatus: Sendable, Equatable {

    /// The connection is healthy and was last exercised successfully.
    case connected

    /// The provider is installed and the user has not rejected it,
    /// but no concrete link exists yet (no CSV imported, no
    /// aggregator institution picked). The coordinator treats this
    /// as "zero upstream accounts".
    case notConnected

    /// The user has not yet approved the consent prompt — the next
    /// action is an explicit authorization request.
    case authorizationRequired

    /// The provider is running but returned partial data on the last
    /// attempt (e.g. one supported institution syncing while another
    /// is offline). Reason is a short log tag, not user copy.
    case degraded(reason: DegradationReason)

    /// The provider is entirely unusable on this device / in this
    /// region / for this entitlement state.
    case unavailable(reason: FinancialDataProviderAvailability.UnavailableReason)

    /// Narrow set of reasons a provider can report partial health.
    /// New reasons should only be added with a code-path that
    /// surfaces honest UI copy for them.
    enum DegradationReason: Sendable, Equatable {

        /// Last sync completed but the coordinator saw more than zero
        /// non-fatal mapping errors (e.g. an account type the bridge
        /// could not classify).
        case partialSync

        /// Provider declined to return fresh balances in the latest
        /// request; cached / user-entered snapshots remain in place.
        case refreshFailed

        /// Structured log label. Never render this directly.
        var logLabel: String {
            switch self {
            case .partialSync: "partial_sync"
            case .refreshFailed: "refresh_failed"
            }
        }
    }
}
