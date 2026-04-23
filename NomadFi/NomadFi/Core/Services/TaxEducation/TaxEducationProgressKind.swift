// TaxEducationProgressKind.swift
// NomadFi
//
// Kind of education item a `TaxEducationProgressRecord` tracks.
// Phase 7B covered lesson + checklist item; Phase 7C adds `.quiz`
// so the same persistence model can record a region-level
// knowledge-check attempt alongside lesson / checklist state.
// Badges and streaks still have no kind here.

import Foundation

/// What a progress record refers to.
enum TaxEducationProgressKind: String, Sendable, Equatable, CaseIterable {

    /// A single `TaxEducationLesson` flagged with
    /// "Mark reviewed" by the user.
    case lesson

    /// A single `TaxEducationChecklistItem` toggled completed
    /// from the region checklist card.
    case checklistItem

    /// A region-level knowledge-check quiz attempt. The record's
    /// `quizID`, `quizScorePercent`, `quizCorrectCount`, and
    /// `quizQuestionCount` fields carry the attempt detail.
    case quiz
}
