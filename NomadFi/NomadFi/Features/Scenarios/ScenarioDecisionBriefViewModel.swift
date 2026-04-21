// ScenarioDecisionBriefViewModel.swift
// NomadFi
//
// Holds the local toggleable state and re-runs the pure engine whenever
// the user confirms a check. Nothing persists — Phase 3 is intentionally
// session-local so no decision appears in the user's data until they
// explicitly act.

import Foundation

/// View model behind the Scenario 1 Amazon arrival-order decision brief.
@MainActor
@Observable
final class ScenarioDecisionBriefViewModel {

    // MARK: - Inputs

    /// The immutable scenario facts. Defaulted to the Scenario 1 fixture.
    let facts: ScenarioFacts

    /// Current user-confirmed guardrail state. Reading or writing this
    /// causes `decision` to update on the next access.
    var state: ScenarioDecisionState

    // MARK: - Init

    init(
        facts: ScenarioFacts = .scenario1,
        state: ScenarioDecisionState = ScenarioDecisionState()
    ) {
        self.facts = facts
        self.state = state
    }

    // MARK: - Derived

    /// The engine's current deterministic decision.
    var decision: ScenarioDecision {
        ScenarioDecisionEngine.decide(facts: facts, state: state)
    }
}
