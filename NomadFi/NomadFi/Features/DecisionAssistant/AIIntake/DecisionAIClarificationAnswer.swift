// DecisionAIClarificationAnswer.swift
// NomadFi
//
// Pure value type for a single user answer to a clarifying
// question. Carries the raw text the user typed (or the picker
// value as text); the view model parses and folds the answer into
// the pending `DecisionDraftInterpretation` on commit.
//
// Honesty contract:
//
//   • `text` is the *raw* user input. Empty / whitespace-only text
//     is allowed at the value-layer level — the view model decides
//     whether an empty answer means "skip" or "keep blank, I'll
//     fill it on the review screen".
//   • The `field` identifies which structured slot the answer
//     resolves. The view model uses it to pick the right binding
//     (review-form text field, currency picker, etc.).

import Foundation

/// One user answer to a single `DecisionAIClarifyingQuestion`.
///
/// The view model converts these into typed values when applying
/// to the pending interpretation, but the value layer itself
/// stays format-agnostic.
struct DecisionAIClarificationAnswer: Sendable, Equatable, Hashable {

    /// The structured field this answer resolves. Mirrors the
    /// `field` on the originating `DecisionAIClarifyingQuestion`.
    let field: DecisionDraftInterpretationMissingField

    /// Raw user input. The view model trims, parses (for amounts),
    /// or maps to enum cases (for currency / kind) on commit.
    let text: String
}
