// DecisionDraftStatus.swift
// NomadFi
//
// Lifecycle state for a user-captured decision draft.
// The Decision Assistant distinguishes analyzed decisions (the
// catalog-backed Scenario 1 record) from user drafts that do not yet
// have a deterministic engine — this enum is how the app marks the
// difference.

import Foundation

/// Pure lifecycle status for a ``DecisionDraftRecord``.
///
/// Persisted as a raw String on the record so CloudKit migrations
/// never have to touch an enum. The two states are deliberately
/// narrow — a draft either still needs a deterministic engine, or
/// the user has archived it. NomadFi never sets this to "analyzed"
/// automatically; that transition is reserved for when a real engine
/// exists and the user opts in.
enum DecisionDraftStatus: String, CaseIterable, Codable, Hashable, Sendable {

    /// The default. NomadFi has captured the user's context but no
    /// deterministic engine covers this draft's kind yet.
    case needsEngine

    /// The user has archived the draft. Hidden from the primary
    /// "Gathered intelligence" list but preserved on-device until
    /// the user opts to delete all data.
    case archived

    // MARK: - Display

    /// Short label used inside a `StatusBadge` on draft rows.
    var displayLabel: String {
        switch self {
        case .needsEngine: "Needs engine"
        case .archived: "Archived"
        }
    }

    /// Longer, VoiceOver-friendly label that never leaves the user
    /// wondering what "Needs engine" means on an assistive read.
    var accessibilityLabel: String {
        switch self {
        case .needsEngine:
            "Captured. Awaiting a deterministic engine — not yet analyzed."
        case .archived:
            "Archived draft."
        }
    }

    /// SF Symbol paired with ``displayLabel`` in the row badge.
    var systemImage: String {
        switch self {
        case .needsEngine: "hourglass"
        case .archived: "archivebox"
        }
    }
}
