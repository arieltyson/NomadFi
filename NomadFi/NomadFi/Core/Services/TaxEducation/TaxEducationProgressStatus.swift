// TaxEducationProgressStatus.swift
// NomadFi
//
// Explicit progress state for a single education item. Phase 7B
// prefers explicit user action everywhere — there is no implicit
// `.inProgress` transition on first open in this slice. The enum
// still carries `.inProgress` so future phases can use it without
// a schema migration.

import Foundation

enum TaxEducationProgressStatus: String, Sendable, Equatable, Comparable, CaseIterable {

    /// No progress record on file, or the record was explicitly
    /// reset.
    case notStarted

    /// Reserved for future phases. Phase 7B never writes this
    /// value — the UI is explicit-only.
    case inProgress

    /// The user explicitly marked the lesson reviewed or toggled
    /// the checklist item completed.
    case completed

    // MARK: - Comparable

    static func < (
        lhs: TaxEducationProgressStatus,
        rhs: TaxEducationProgressStatus
    ) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .notStarted: 0
        case .inProgress: 1
        case .completed: 2
        }
    }

    /// Convenience wrapper for persisted raw values. Missing or
    /// unknown strings fall back to `.notStarted` so the UI never
    /// has to branch on `nil`.
    static func from(rawValue: String?) -> TaxEducationProgressStatus {
        guard let rawValue,
              let parsed = TaxEducationProgressStatus(rawValue: rawValue)
        else {
            return .notStarted
        }
        return parsed
    }
}
