// ContinueAmazonArrivalDecisionIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Continue my payment decision in NomadFi."
// Opens NomadFi to the Decision Assistant *and* speaks a short scene-setter
// with the engine's current ruling, so the dialog and the app agree.

import AppIntents
import SwiftData

/// Resumes the Amazon arrival-order decision in-app.
///
/// Pairs a foreground-immediate mode with a ``MainTabSelection``
/// hand-off to land the user on the Decision Assistant, then speaks a
/// short dialog that carries the engine's current ruling. If the
/// record has no user inputs, the dialog says exactly that instead
/// of pretending a path has been chosen.
///
/// **Supported mode:** `.foreground(.immediate)` — the app is
/// brought forward before `perform()` executes so the
/// `UserDefaults` write and the subsequent `MainTabView` read happen
/// against the foregrounded host process, guaranteeing the Decisions
/// tab is the surface the user sees first.
struct ContinueAmazonArrivalDecisionIntent: AppIntent {

    static let title: LocalizedStringResource = "Continue Amazon Arrival Decision"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi on the Decision Assistant so you can finish your Amazon arrival-order decision."
    )

    /// Resumes the decision in-app — this is a navigation intent.
    /// `.foreground(.immediate)` is the iOS 18+ replacement for the
    /// deprecated `openAppWhenRun = true`.
    static let supportedModes: IntentModes = .foreground(.immediate)

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        DecisionsRoute.request()

        let brief = try DecisionAssistantIntentContext.loadAmazonArrivalBrief()
        let dialog = DecisionAssistantIntentDialog.continueAmazonArrivalDecision(
            brief: brief
        )
        return .result(dialog: "\(dialog)")
    }
}
