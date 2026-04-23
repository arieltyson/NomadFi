// ActiveCardIntent.swift
// NomadFi
//
// Legacy Siri intent previously registered for the generic "Which
// card should I use?" phrase. The original implementation ranked
// accounts by `foreignTransactionFeePercent` alone; that FX-fee-only
// heuristic is retired.
//
// Generic "Which card…" voice routing now points at
// ``RecommendCardIntent`` (backed by ``PurchaseDecisionEngine``).
// This type remains as a deprecated alias so user-created shortcuts
// in the Shortcuts app that were recorded against `ActiveCardIntent`
// keep resolving — it is NOT exposed through
// ``NomadFiShortcuts.appShortcuts`` anymore.
//
// When invoked, it defers to the Scenario 1 brief so the answer
// stays deterministic and source-cited, matching what the user would
// see if they tapped the in-app "Review my Amazon order" shortcut.

import AppIntents
import SwiftData

/// Deprecated legacy voice entry point. Defers to the Scenario 1
/// engine so callers that still trigger this intent get a calm,
/// honest Amazon-arrival summary instead of an invented ranking.
/// Prefer ``RecommendCardIntent`` for new voice flows.
struct ActiveCardIntent: AppIntent {

    static let title: LocalizedStringResource = "Which Card Should I Use?"

    static let description: IntentDescription = IntentDescription(
        "Get NomadFi's current saved Amazon arrival-order recommendation from the Decision Assistant."
    )

    /// Voice-first: the dialog summarises the engine's ruling and
    /// asks the user to finish the brief in-app when checks remain.
    /// `.background` is the iOS 18+ replacement for the deprecated
    /// `openAppWhenRun = false` — the intent never needs to bring
    /// NomadFi to the foreground.
    static let supportedModes: IntentModes = .background

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let brief = try DecisionAssistantIntentContext.loadAmazonArrivalBrief()
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(brief: brief)
        return .result(dialog: "\(dialog)")
    }
}
