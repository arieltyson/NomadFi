// TaxEducationProgressKind.swift
// NomadFi
//
// Kind of education item a `TaxEducationProgressRecord` tracks.
// Scope is intentionally narrow in Phase 7B — just lesson and
// checklist item. Quizzes and badges have no kind here yet.

import Foundation

/// What a progress record refers to.
enum TaxEducationProgressKind: String, Sendable, Equatable, CaseIterable {

    /// A single `TaxEducationLesson` flagged with
    /// "Mark reviewed" by the user.
    case lesson

    /// A single `TaxEducationChecklistItem` toggled completed
    /// from the region checklist card.
    case checklistItem
}
