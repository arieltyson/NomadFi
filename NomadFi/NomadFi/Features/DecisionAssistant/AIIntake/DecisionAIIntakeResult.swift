// DecisionAIIntakeResult.swift
// NomadFi
//
// Discriminated union returned by `DecisionDraftInterpreter.interpret(...)`.
// Splits the success path (`interpreted`) from the failure path
// (`failed`) so the intake view model can render a calm error
// state without throwing across the actor boundary.

import Foundation

/// Result of a single AI intake interpretation. Either a structured
/// draft sketch the user can review, or a short factual error the
/// intake sheet renders verbatim. Never a thrown error — the
/// interpreter swallows transport errors and turns them into
/// `.failed` so the UI stays declarative.
enum DecisionAIIntakeResult: Sendable, Equatable, Hashable {

    /// Successful structured extraction. The intake sheet hands
    /// this to its review form.
    case interpreted(DecisionDraftInterpretation)

    /// Interpreter could not extract a structured draft. The
    /// associated string is a short, factual explanation safe to
    /// render directly to the user.
    case failed(reason: String)
}
