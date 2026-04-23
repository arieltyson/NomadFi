// TaxEducationProgressKind.swift
// NomadFi
//
// Kind of education item a `TaxEducationProgressRecord` tracks.
// Phase 7B covered lesson + checklist item; Phase 7C adds `.quiz`
// so the same persistence model can record a region-level
// knowledge-check attempt alongside lesson / checklist state.
// Calm recognition badges are derived from these kinds inside
// `TaxEducationRecognitionComputer` — they intentionally do not
// need their own persisted kind.

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
