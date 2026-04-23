// FinancialDataProviderKind.swift
// NomadFi
//
// Typed identity for each class of financial-data provider NomadFi can
// talk to. The kind is the seam the product uses to reason about
// availability, provenance, and fallback. The app never treats any
// single kind as load-bearing: manual/import paths remain viable even
// when FinanceKit or a future aggregator is offline or entitlement-gated.
//
// Design notes:
// - `.manual` is always present. It represents the user-typed truth
//   that already lives in SwiftData via ``Account`` / ``Transaction``.
// - `.csvImport` represents the deterministic file-import pipeline in
//   `Core/Services/Import/`. Imports are user-initiated, so "sync" is
//   a no-op; the kind exists so the coordinator can label provenance.
// - `.financeKit` wraps Apple's on-device framework. Availability is
//   entitlement-gated and region-limited (US: Apple Card, Apple Cash,
//   Savings; UK: selected open-banking institutions). The data stays
//   on-device; Apple never sees it.
// - `.externalAggregator` is the *boundary* for a later third-party
//   provider (Plaid / MX / Akoya / Finicity). NomadFi does not ship
//   an aggregator SDK today; this case exists so the coordinator /
//   UI can represent an unlinked-by-design seam and so a later
//   provider can be plugged in without touching core engines. The
//   associated identifier is opaque on purpose — the core domain
//   model never hard-codes a vendor name.

import Foundation

/// Identifies which class of provider a snapshot, connection, or sync
/// event came from. Used by the coordinator to pick fallbacks and by
/// UI to surface honest provenance labels.
enum FinancialDataProviderKind: Hashable, Sendable {

    /// The user-typed source of truth in NomadFi's SwiftData store.
    /// Always available; never entitlement-gated.
    case manual

    /// Deterministic CSV import (`Core/Services/Import/`). Available
    /// whenever the app itself is installed; no external dependency.
    case csvImport

    /// Apple's on-device FinanceKit bridge. Availability is
    /// entitlement-gated, region-limited, and institution-limited.
    /// When unavailable, the coordinator must degrade to other
    /// providers rather than block the core experience.
    case financeKit

    /// Placeholder seam for a later permissioned aggregator
    /// (e.g. Plaid / MX / Akoya / Finicity). NomadFi does not ship
    /// any such SDK today. The associated identifier lets a future
    /// implementation distinguish between candidates during a
    /// bakeoff without leaking vendor-specific types into the core
    /// domain model.
    case externalAggregator(identifier: String)

    /// Short, non-vendor-marketing label for logs and UI rows.
    /// Never implies institutional coverage NomadFi does not have.
    var displayLabel: String {
        switch self {
        case .manual: "Manual entry"
        case .csvImport: "CSV import"
        case .financeKit: "Apple FinanceKit"
        case .externalAggregator(let identifier):
            identifier.isEmpty ? "External aggregator" : "External aggregator (\(identifier))"
        }
    }

    /// Whether this provider is gated by an Apple / regulator /
    /// third-party managed entitlement or contract. UI uses this to
    /// decide whether to surface a "not yet available" explanation
    /// versus a "connect" action.
    var isEntitlementGated: Bool {
        switch self {
        case .manual, .csvImport: false
        case .financeKit, .externalAggregator: true
        }
    }

    /// Stable string key for use in log context, hashable sets, or
    /// persistence that doesn't need the associated value of
    /// `.externalAggregator`. Never surface this to the user.
    var logKey: String {
        switch self {
        case .manual: "manual"
        case .csvImport: "csv_import"
        case .financeKit: "finance_kit"
        case .externalAggregator(let identifier):
            identifier.isEmpty ? "external_aggregator" : "external_aggregator.\(identifier)"
        }
    }

    /// Projects the kind onto the persisted ``FinancialSnapshotSource``
    /// used on ``Account`` rows, so engines and UI that already consume
    /// snapshot provenance can keep doing so without a migration.
    /// `.externalAggregator` maps to ``FinancialSnapshotSource/imported``
    /// for now — it is user-consented external data in the same shape
    /// as a CSV would be, and the core domain model never needs to
    /// disambiguate further today.
    var persistedSnapshotSource: FinancialSnapshotSource {
        switch self {
        case .manual: .userSnapshot
        case .csvImport: .imported
        case .financeKit: .financeKit
        case .externalAggregator: .imported
        }
    }
}
