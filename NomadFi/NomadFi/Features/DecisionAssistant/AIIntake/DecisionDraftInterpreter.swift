// DecisionDraftInterpreter.swift
// NomadFi
//
// Protocol seam between the intake view layer and the underlying
// model. Lets the SwiftUI sheet stay testable without the real
// Foundation Models dependency: production wires up
// `FoundationModelsDraftInterpreter`, tests and previews wire up
// `PreviewDecisionDraftInterpreter`.
//
// Honesty contract pinned in `DecisionAIIntakeTests`:
//
//   • The interpreter never persists anything. It produces a
//     value-typed `DecisionAIIntakeResult` that the UI must show
//     for explicit user confirmation before a `DecisionDraftRecord`
//     is created.
//   • The interpreter never produces a recommendation. Its output
//     is structured *input*; the deterministic engines downstream
//     (Purchase Card Check, Credit Timing) remain the source of
//     truth for any actual decision.
//   • Implementations declare an availability state up-front so
//     the UI can render an honest fallback instead of pretending
//     Apple Intelligence is everywhere.

import Foundation

/// Marker protocol for any layer that can turn natural-language
/// scenario text into a structured `DecisionDraftInterpretation`.
/// `Sendable` so the protocol composes with strict-concurrency
/// callers; conforming types may still be `@MainActor`-bound at
/// the call site.
protocol DecisionDraftInterpreter: Sendable {

    /// Synchronous availability snapshot. Cheap to call — the
    /// intake view model reads this on appear so it can render a
    /// calm unavailable state without spinning up a session.
    func availability() -> DecisionAIIntakeAvailability

    /// Asynchronously interprets a free-form scenario into a
    /// structured `DecisionDraftInterpretation`. Implementations
    /// must:
    ///
    ///   • Reject empty / whitespace-only input upstream by
    ///     returning `.failed(...)` rather than spinning up a
    ///     model session.
    ///   • Never produce a recommendation, "verified", "best
    ///     card", or "analyzed" string.
    ///   • Treat all transport / model errors as
    ///     `.failed(reason:)` — never throw across the boundary.
    func interpret(scenarioText: String) async -> DecisionAIIntakeResult
}
