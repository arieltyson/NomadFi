// ContinueAmazonArrivalDecisionIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Continue my payment decision in NomadFi."
// Opens NomadFi to the Decisions tab *and* speaks a short scene-setter
// with the engine's current ruling, so the dialog and the app agree.

import AppIntents
import SwiftData

/// Resumes the Amazon arrival-order decision in-app.
///
/// Pairs `openAppWhenRun = true` with a `MainTabSelection` hand-off
/// to land the user on the Decisions tab, then speaks a short
/// dialog that carries the engine's current ruling. If the record
/// has no user inputs, the dialog says exactly that instead of
/// pretending a path has been chosen.
struct ContinueAmazonArrivalDecisionIntent: AppIntent {

    static let title: LocalizedStringResource = "Continue Amazon Arrival Decision"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi on the Decisions tab so you can finish your Amazon arrival-order decision."
    )

    /// Resumes the decision in-app — this is a navigation intent.
    static let openAppWhenRun = true

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(
            MainTabSelection.decisions.rawValue,
            forKey: MainTabSelection.storageKey
        )

        let brief = try DecisionAssistantIntentContext.loadAmazonArrivalBrief()
        let dialog = DecisionAssistantIntentDialog.continueAmazonArrivalDecision(
            brief: brief
        )
        return .result(dialog: "\(dialog)")
    }
}
