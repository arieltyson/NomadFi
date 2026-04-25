// DecisionAIClarificationPlanner.swift
// NomadFi
//
// Pure namespace that turns "the model interpreted this scenario
// as kind X and these required fields are still empty" into the
// bounded `DecisionAIClarificationPlan` the intake sheet walks the
// user through. Lives in its own file so the rule is fully
// decoupled from the SwiftUI view, the view model, the
// interpreter, and SwiftData.
//
// Honesty contract pinned in `DecisionAIClarificationPlannerTests`:
//
//   • Bounded — the plan is capped at
//     `DecisionAIClarificationPlan.maxQuestions`. Excess gaps stay
//     resolvable on the existing review form.
//   • Kind-aware — only fields the kind genuinely *requires* are
//     considered. Non-purchase kinds (`creditTiming`,
//     `taxEducation`, `investingEducation`, `other`) never produce
//     purchase-shaped questions because their required-field set
//     is empty by design (see `DecisionDraftKindCompleteness`).
//   • Deterministic — same kind + same missing set always yields
//     the same plan in the same order.
//   • Ordered — questions follow
//     `DecisionDraftInterpretationMissingField.allCases` so the
//     intake sheet shows them in a stable, predictable sequence
//     across re-interpretations.
//
// Per Apple's Generative AI HIG: the planner exists so the user
// is asked at most a small, finite number of focused questions
// before being handed back control on the review screen.

import Foundation

/// Pure planner that decides which clarifying questions to ask.
enum DecisionAIClarificationPlanner {

    /// Builds the bounded clarification plan for the given kind +
    /// missing-field set. The caller produces `missingFields` via
    /// `DecisionDraftInterpretationCompleteness.missingFields(in:)`
    /// so the planner does not have to re-walk the interpretation.
    ///
    /// Returns `.none` (an empty plan) when no kind-required field
    /// is missing. Otherwise returns up to
    /// `DecisionAIClarificationPlan.maxQuestions` ordered questions.
    static func plan(
        kind: DecisionDraftKind,
        missingFields: [DecisionDraftInterpretationMissingField]
    ) -> DecisionAIClarificationPlan {
        let required = DecisionDraftKindCompleteness.requiredFields(for: kind)
        guard !required.isEmpty else { return .none }

        // Walk `allCases` so the order is stable across runs;
        // intersect with required + the supplied missing list so we
        // ask only about gaps that actually matter for this kind.
        let askable = DecisionDraftInterpretationMissingField.allCases.filter { field in
            required.contains(field) && missingFields.contains(field)
        }

        let bounded = Array(askable.prefix(DecisionAIClarificationPlan.maxQuestions))
        let questions = bounded.map { Self.question(for: $0, kind: kind) }
        return DecisionAIClarificationPlan(questions: questions)
    }

    // MARK: - Per-field question copy

    /// Per-field question copy. Kept here so the planner is a
    /// single source of truth for clarification prompts and so the
    /// copy-guard tests can scan one file for prohibited
    /// recommendation language.
    ///
    /// Wording rules (mirrors Apple HIG generative-AI guidance):
    ///   • Short, neutral, present-tense.
    ///   • Never uses "best", "recommended", "verified", or
    ///     "analyzed" — the model is structuring input, not
    ///     deciding anything.
    ///   • The optional `helper` explains *why* NomadFi is asking,
    ///     not what the user "should" do.
    private static func question(
        for field: DecisionDraftInterpretationMissingField,
        kind _: DecisionDraftKind
    ) -> DecisionAIClarifyingQuestion {
        switch field {
        case .amount:
            return DecisionAIClarifyingQuestion(
                field: .amount,
                prompt: "How much is this scenario about?",
                helper: "A number in your own words is fine — NomadFi will not pick a card or account on your behalf.",
                inputKind: .amount(placeholder: "Amount")
            )
        case .currencyCode:
            return DecisionAIClarifyingQuestion(
                field: .currencyCode,
                prompt: "Which currency is this in?",
                helper: "Helps NomadFi reason about FX honestly later — the typed form lets you change it.",
                inputKind: .currency
            )
        case .merchantName:
            return DecisionAIClarifyingQuestion(
                field: .merchantName,
                prompt: "Who are you paying or buying from?",
                helper: nil,
                inputKind: .shortText(placeholder: "Merchant or counterparty")
            )
        case .locationText:
            return DecisionAIClarifyingQuestion(
                field: .locationText,
                prompt: "Where will this happen?",
                helper: "Short context only — a city or country is enough.",
                inputKind: .shortText(placeholder: "City or context")
            )
        case .timingText:
            return DecisionAIClarifyingQuestion(
                field: .timingText,
                prompt: "When does this happen?",
                helper: "In your own words — NomadFi does not parse this into a calendar date.",
                inputKind: .shortText(placeholder: "Timing")
            )
        case .title:
            return DecisionAIClarifyingQuestion(
                field: .title,
                prompt: "Give this draft a short name?",
                helper: "Optional — helps you find the draft later. You can edit it on the review screen too.",
                inputKind: .shortText(placeholder: "Short title")
            )
        case .kind:
            return DecisionAIClarifyingQuestion(
                field: .kind,
                prompt: "Which kind of decision is this?",
                helper: "Pick the closest match — the typed form lets you change it later.",
                inputKind: .kind
            )
        }
    }
}
