// PreviewDecisionDraftInterpreter.swift
// NomadFi
//
// Deterministic test / preview implementation of
// `DecisionDraftInterpreter`. Holds a fixed availability state and
// a fixed result so SwiftUI previews and Swift Testing suites can
// exercise the intake sheet end-to-end without Apple Intelligence
// or Foundation Models on the host.
//
// Used by:
//   • `DecisionAIIntakeTests` — to pin view-model state
//     transitions across availability + result combinations.
//   • SwiftUI previews — to render the sheet in a known good
//     state without spinning up the system model.

import Foundation

/// Sendable, deterministic interpreter. Constructed with the
/// exact `availability()` value to return and either a stock
/// result or a closure that builds one from the input text.
struct PreviewDecisionDraftInterpreter: DecisionDraftInterpreter {

    let stubbedAvailability: DecisionAIIntakeAvailability
    let stubbedResult: @Sendable (String) -> DecisionAIIntakeResult

    init(
        availability: DecisionAIIntakeAvailability = .available,
        stubbedResult: @escaping @Sendable (String) -> DecisionAIIntakeResult
    ) {
        self.stubbedAvailability = availability
        self.stubbedResult = stubbedResult
    }

    init(
        availability: DecisionAIIntakeAvailability = .available,
        result: DecisionAIIntakeResult
    ) {
        self.stubbedAvailability = availability
        self.stubbedResult = { _ in result }
    }

    func availability() -> DecisionAIIntakeAvailability {
        stubbedAvailability
    }

    func interpret(scenarioText: String) async -> DecisionAIIntakeResult {
        let trimmed = scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failed(reason: "Add a scenario before requesting an interpretation.")
        }
        return stubbedResult(trimmed)
    }
}
