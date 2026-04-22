// FinancialSnapshotSource.swift
// NomadFi
//
// Provenance for a live financial snapshot (current balance, available
// credit, statement balance). A snapshot is a point-in-time value that
// goes stale as soon as the user transacts — this enum lets the UI
// honestly label where the number came from and how much trust to
// place in it.

import Foundation

/// Where a live financial snapshot on an ``Account`` originated.
///
/// Snapshots are explicitly not stable profile facts. A snapshot with
/// source ``userSnapshot`` reflects the user reading their issuer app
/// and entering the number by hand; ``financeKit`` reflects a future
/// Apple-mediated sync; ``unknown`` covers legacy rows migrated into
/// the new schema before a source was recorded.
enum FinancialSnapshotSource: String, Codable, CaseIterable, Sendable {

    /// The user opened their issuer/bank app and typed the value in.
    /// This is the canonical manual path in Phase 1.
    case userSnapshot = "user_snapshot"

    /// Pre-snapshot manual entry (e.g. a legacy ``Account/balance``
    /// value migrated forward). Retained so UI can show a distinct
    /// "not a true snapshot" label for rows that pre-date snapshots.
    case manualEntry = "manual_entry"

    /// Imported from a CSV, bank export, or other file source the
    /// user supplied. Reserved for Phase 4.
    case imported = "imported"

    /// Read from Apple's FinanceKit bridge. Reserved for Phase 5.
    case financeKit = "finance_kit"

    /// Source is not recorded — neither user-entered nor synced.
    /// Treated as the lowest-trust source.
    case unknown = "unknown"

    /// Human-readable label for UI rows and accessibility descriptions.
    var displayName: String {
        switch self {
        case .userSnapshot: "You entered this"
        case .manualEntry: "Manual entry"
        case .imported: "Imported"
        case .financeKit: "Apple FinanceKit"
        case .unknown: "Source unknown"
        }
    }
}

extension FinancialSnapshotSource {

    /// How long a snapshot from this source is considered fresh before
    /// the UI should start labelling it as stale. FinanceKit syncs on a
    /// short cadence, so its window is tighter than a user-entered
    /// snapshot that only refreshes when the user remembers to edit.
    var freshnessWindow: TimeInterval {
        switch self {
        case .userSnapshot: 60 * 60 * 24 * 7        // 7 days
        case .manualEntry: 60 * 60 * 24 * 7         // 7 days
        case .imported: 60 * 60 * 24 * 14           // 14 days
        case .financeKit: 60 * 60 * 24              // 1 day
        case .unknown: 60 * 60 * 24                 // 1 day — distrust by default
        }
    }
}
