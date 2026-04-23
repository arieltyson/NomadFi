// TaxEducationQuizQuestion.swift
// NomadFi
//
// Single-answer multiple-choice question. Each question traces
// back to an existing lesson (`sourceLessonID`) so the quiz
// catalogue can never drift away from the locally-authored,
// source-backed lesson catalogue.
//
// Authoring rules (pinned by `TaxEducationQuizCatalogTests`):
//   • Exactly one `correctOptionID` that appears in `options`.
//   • 2–4 options per question.
//   • No professional-judgment phrasing, no "you qualify" /
//     "deductible" claims in the prompt or explanation.

import Foundation

struct TaxEducationQuizQuestion: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — scoped by the owning quiz's id.
    let id: String

    /// The question prompt. Keep it concise and declarative.
    let prompt: String

    /// 2–4 answer options. Order is authoring intent; the UI
    /// preserves it so the catalogue tests can pin indices.
    let options: [TaxEducationQuizOption]

    /// Id of the correct option. Must match one of `options`.
    let correctOptionID: String

    /// Short one-line explanation shown after submit. Always
    /// procedural — never "you qualify" / "you should file".
    let explanation: String

    /// Id of the lesson this question is sourced from. Validated
    /// by `TaxEducationQuizCatalog.isBacked(by:inCatalog:)` so a
    /// future catalogue edit can't leave a quiz orphaned.
    let sourceLessonID: String
}
