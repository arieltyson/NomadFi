// DecisionAIClarificationPlan.swift
// NomadFi
//
// Pure value type that holds the ordered list of follow-up
// questions the intake sheet should walk the user through after
// initial interpretation. The plan is built by
// `DecisionAIClarificationPlanner` and is *bounded* — never more
// than `maxQuestions` entries — so the flow stays a short
// progressive-disclosure sequence rather than a chat loop.
//
// Honesty contract pinned in `DecisionAIClarificationPlannerTests`:
//
//   • The plan is a flat list. There is no branching logic, no
//     conditional follow-ups, no model-driven question generation.
//     Each question targets one structured field and is decided
//     up-front from the kind-aware completeness rules.
//   • The plan is *bounded*. If kind-required missing fields
//     exceed `maxQuestions`, the planner truncates so the flow
//     stays calm. The remaining gaps surface verbatim on the
//     review sheet, where the user resolves them with the typed
//     form — same controls they would have hit anyway.

import Foundation

/// Bounded, ordered set of clarifying questions for a single
/// interpretation. Built by `DecisionAIClarificationPlanner`.
struct DecisionAIClarificationPlan: Sendable, Equatable, Hashable {

    /// Hard cap on the number of follow-up questions the intake
    /// sheet will surface in a single clarification loop.
    /// Keeps the flow finite and predictable per Apple's HIG
    /// guidance to "ask before significant actions" without
    /// turning the intake into an open conversation.
    static let maxQuestions = 3

    /// Ordered questions. Always ≤ `maxQuestions`. May be empty —
    /// callers check `isEmpty` to short-circuit straight to the
    /// review screen when no clarification is needed.
    let questions: [DecisionAIClarifyingQuestion]

    /// `true` when the plan has nothing to ask. Drives the
    /// "interpretation → review" short-circuit.
    var isEmpty: Bool { questions.isEmpty }

    /// Convenience for "how many gaps the user will be walked
    /// through". Matches `questions.count` and is capped by
    /// `maxQuestions`.
    var count: Int { questions.count }

    /// Convenience constant for the "no clarification needed" plan.
    static let none = DecisionAIClarificationPlan(questions: [])
}
