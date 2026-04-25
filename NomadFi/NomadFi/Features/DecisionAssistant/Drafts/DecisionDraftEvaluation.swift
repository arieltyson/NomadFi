// DecisionDraftEvaluation.swift
// NomadFi
//
// Pure value type the Phase 1 follow-through evaluator returns for
// a captured draft. Carries:
//
//   • a deterministic `engineCoverage` label that names how the
//     draft maps to NomadFi's existing engines today,
//   • a procedural `headline` the detail view renders above the
//     action buttons,
//   • the ordered list of next actions the user can take.
//
// Everything is value-typed and `Sendable` — the evaluator is pure
// over its inputs, so the same draft + same account snapshot
// always yields the same evaluation. No persistence, no mutation
// of the draft itself.

import Foundation

/// Deterministic, on-demand evaluation of one draft. Built by
/// `DecisionDraftEvaluator.evaluate(...)`. Never persisted —
/// recomputed every time the detail view renders.
struct DecisionDraftEvaluation: Sendable, Equatable, Hashable {

    /// Coverage state for the draft's kind and current context.
    let engineCoverage: DecisionDraftEngineCoverage

    /// Short, factual sentence rendered as the section header on
    /// the detail view ("What NomadFi can do now"). Always
    /// procedural — never claims a recommendation.
    let headline: String

    /// Ordered next actions the user can take. Empty when the
    /// kind is `.other` and there is genuinely nothing to do.
    let nextActions: [DecisionDraftNextAction]

    // MARK: - Derived

    /// Convenience flag used by the detail view to decide whether
    /// to render the section's section header at all.
    var hasContent: Bool {
        !nextActions.isEmpty || !headline.isEmpty
    }

    /// The single handoff action, if exactly one exists. Used by
    /// callers (e.g. the detail-view router) that need a stable
    /// entry-point for the draft's primary action.
    var primaryHandoff: DecisionDraftNextAction? {
        nextActions.first(where: \.isHandoff)
    }
}
