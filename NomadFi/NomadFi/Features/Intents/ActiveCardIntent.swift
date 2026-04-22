// ActiveCardIntent.swift
// NomadFi
//
// Siri shortcut: "Hey Siri, which card should I use?"
//
// The original implementation sorted accounts by
// `foreignTransactionFeePercent` and announced the lowest-fee card as
// the recommendation. That shortcut is retained for phrase
// compatibility, but the behaviour is now routed through the Scenario
// 1 decision engine so voice answers stay consistent with the app's
// Decision Assistant — no fee-only heuristic, no invented rankings.

import AppIntents
import SwiftData

/// Responds to "Which card should I use?" via the Scenario 1 engine.
///
/// NomadFi does not yet ship a generic merchant-agnostic card
/// recommendation engine, so this intent is intentionally honest:
/// today it can only answer the saved Amazon arrival-order decision,
/// and it defers to `ScenarioDecisionEngine` for the ruling. If the
/// user has not entered any scenario inputs yet, the dialog says so
/// instead of fabricating an answer.
///
/// Usage: "Hey Siri, which card should I use in NomadFi?"
struct ActiveCardIntent: AppIntent {

    static let title: LocalizedStringResource = "Which Card Should I Use?"

    static let description: IntentDescription = IntentDescription(
        "Get NomadFi's current saved Amazon arrival-order recommendation from the Decision Assistant."
    )

    /// Voice-first: the dialog summarises the engine's ruling and
    /// asks the user to finish the brief in-app when checks remain.
    static let openAppWhenRun = false

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let brief = try DecisionAssistantIntentContext.loadAmazonArrivalBrief()
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(brief: brief)
        return .result(dialog: "\(dialog)")
    }
}
