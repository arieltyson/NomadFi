// DecisionDraftEngineCoverage.swift
// NomadFi
//
// Pure value type that names how a captured draft maps to NomadFi's
// existing deterministic engines today. Phase 1 follow-through:
// drafts stay non-automatic — the evaluator only describes what
// NomadFi *can* do if the user explicitly opts in. The evaluator
// never changes the draft's persisted `DecisionDraftStatus`.

import Foundation

/// How a draft maps to a deterministic engine right now. Each case
/// is observable in the detail view's "What NomadFi can do now"
/// section so the user always sees an honest, factual readiness
/// state rather than a generic "Needs engine" label.
enum DecisionDraftEngineCoverage: Sendable, Equatable, Hashable {

    /// A deterministic engine covers this draft and the captured
    /// fields are sufficient to hand off without nagging the user
    /// for more context first.
    case engineReady

    /// A deterministic engine covers this draft but the user needs
    /// to add more context before NomadFi can hand off cleanly.
    /// `missing` is a procedural list — never accusatory.
    case engineRequiresMoreContext(missing: [String])

    /// No deterministic engine covers this draft yet, but NomadFi
    /// already ships an in-app source-backed surface (Tax Vault or
    /// Investing Learn) the user can review next. The detail view
    /// surfaces a calm note with the path; it does not deep-link.
    case routedToAdvancedTool

    /// No deterministic engine and no advanced tool that fits the
    /// draft. The detail view shows the captured fields and a
    /// calm "no engine yet" note — never auto-analyzes.
    case noEngineYet
}
