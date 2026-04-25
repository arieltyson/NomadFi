// DecisionAIClarifyingQuestion.swift
// NomadFi
//
// Pure value type for a single follow-up question the intake
// sheet asks the user when the on-device interpretation left a
// kind-required field empty.
//
// Honesty contract:
//
//   • Every question is rooted in one specific
//     `DecisionDraftInterpretationMissingField`. The UI never
//     improvises a question without a backing missing field — that
//     would violate "ask before significant actions" by asking
//     about something the deterministic engine doesn't actually
//     need.
//   • Copy is *short* (`prompt`) plus an *optional* one-line
//     explanation (`helper`). The helper exists to clarify *why*
//     NomadFi is asking, not to lecture; the UI hides it when nil.
//   • `inputKind` decides which input control the sheet renders
//     (short text, decimal amount, currency picker, kind picker).
//     Centralising this in the value layer keeps the view a thin
//     render and lets the planner choose appropriate controls
//     without the view having to branch on field semantics.

import Foundation

/// A single, narrow follow-up question the intake sheet renders to
/// resolve a kind-required missing field. Identifiable by its
/// `field` so SwiftUI can animate the clarification list cleanly.
struct DecisionAIClarifyingQuestion: Sendable, Equatable, Hashable, Identifiable {

    /// The structured field this question resolves. Drives both
    /// `inputKind` and the apply-side logic on the view model.
    let field: DecisionDraftInterpretationMissingField

    /// Short, specific, neutrally-worded question. Present-tense,
    /// no marketing language, no recommendation framing.
    let prompt: String

    /// Optional one-line explanation of *why* NomadFi is asking.
    /// `nil` when the prompt is self-explanatory; the UI hides the
    /// row entirely in that case so the question stays calm.
    let helper: String?

    /// Which input control the intake sheet should render for this
    /// question.
    let inputKind: InputKind

    /// Stable identity so `ForEach` and animations in the
    /// clarification UI key on the field, not the array index.
    var id: DecisionDraftInterpretationMissingField { field }

    // MARK: - Input control kinds

    /// Discrete enum of the input controls the intake sheet knows
    /// how to render for a clarification question. Each case maps
    /// to a single SwiftUI control choice; the view never branches
    /// on `field` directly.
    enum InputKind: Sendable, Equatable, Hashable {

        /// `TextField` (single line). `placeholder` is rendered as
        /// the prompt text inside the field.
        case shortText(placeholder: String)

        /// `TextField(.decimalPad)` for a numeric amount.
        /// `placeholder` is the prompt rendered inside the field
        /// (typically a currency code, e.g. "USD").
        case amount(placeholder: String)

        /// `Picker` over `CurrencyCode.allCases`.
        case currency

        /// `Picker` over `DecisionDraftKind.allCases`. Surfaces only
        /// when the model genuinely could not classify the kind.
        case kind
    }
}
