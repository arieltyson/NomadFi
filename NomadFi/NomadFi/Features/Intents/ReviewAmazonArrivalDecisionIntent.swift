// ReviewAmazonArrivalDecisionIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Review my Amazon order in NomadFi."
// Summarises the Scenario 1 engine's current ruling and outstanding
// checks via voice, without opening the app.

import AppIntents
import SwiftData

/// Voice-friendly status read for the Amazon arrival-order decision.
///
/// Loads the saved Scenario 1 record, runs the deterministic engine,
/// and returns a concise dialog that carries:
///
///   - the current ruling (from `ScenarioDecisionEngine`)
///   - how many outstanding checks the engine still wants cleared
///   - a "no inputs yet" caveat when the record is empty, instead of
///     fabricating a recommendation
///
/// The intent never advertises "verified" framing — the engine's
/// evidence model already handles source confidence in the brief.
struct ReviewAmazonArrivalDecisionIntent: AppIntent {

    static let title: LocalizedStringResource = "Review Amazon Arrival Decision"

    static let description: IntentDescription = IntentDescription(
        "Hear NomadFi's current source-backed ruling for your Amazon arrival-order decision."
    )

    /// Voice-first summary — the app is not required for the answer.
    static let openAppWhenRun = false

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let brief = try DecisionAssistantIntentContext.loadAmazonArrivalBrief()
        let dialog = DecisionAssistantIntentDialog.amazonArrivalReview(brief: brief)
        return .result(dialog: "\(dialog)")
    }
}
