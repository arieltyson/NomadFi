// OpenAIIntakeIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Capture this with Apple Intelligence in
// NomadFi." Routes a voice or Shortcuts launch into the existing
// in-app on-device AI intake flow with a scenario string already
// pre-seeded, then hands control back to the user — clarification
// loop, review, and explicit save all happen in-app.
//
// Why a foreground intent (mirrors `OpenDecisionAssistantIntent`):
//   The user's purpose is to *continue* a flow inside NomadFi —
//   read clarifying questions, edit fields, decide what to save.
//   `.foreground(.immediate)` is the iOS 18+ replacement for
//   `openAppWhenRun = true` and the only mode that lets the
//   Decision Assistant mount before this intent's dialog is spoken,
//   so the user sees the AI sheet appear right after the spoken
//   acknowledgement.
//
// Why this intent does not interpret, save, or recommend:
//   Per the Phase 9A system-surface follow-through brief, the
//   intent is *navigation only* — it sets the tab, hands the
//   pre-seeded scenario across via
//   `PendingAIIntakeRequestStore`, and returns. Interpretation
//   stays on-device inside `FoundationModelsDraftInterpreter`,
//   the bounded clarifying loop stays in-app, and persistence
//   only ever fires when the user taps Save in the existing
//   review screen. No background analysis, no networked LLM, no
//   recommendation generation — same honesty contract as the
//   in-app flow.
//
// Availability fallback:
//   If Foundation Models / Apple Intelligence is unavailable on
//   this device, the in-app sheet already renders the calm
//   unavailable-state surface from `DecisionAIIntakeAvailability`
//   with a "Capture with the typed form instead" affordance. We
//   don't fake capability here — we just route the user to the
//   surface that knows how to degrade honestly.

import AppIntents
import Foundation

/// Opens NomadFi on the Decision Assistant and pre-seeds the on-device
/// AI intake sheet with a scenario string. The user reviews
/// clarifying questions, edits the extracted fields, and explicitly
/// saves — same bounded flow as the in-app entry point.
struct OpenAIIntakeIntent: AppIntent {

    static let title: LocalizedStringResource = "Describe a Decision"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi with the scenario you dictated filled in, ready for on-device AI to structure. NomadFi never analyzes or saves anything until you confirm in the app."
    )

    /// Explicit app launch — the user is asking NomadFi to open
    /// and continue the AI intake flow. `.foreground(.immediate)`
    /// is the iOS 18+ replacement for the deprecated
    /// `openAppWhenRun = true` and matches `OpenDecisionAssistantIntent`.
    static let supportedModes: IntentModes = .foreground(.immediate)

    // MARK: - Parameters

    @Parameter(
        title: "Scenario",
        description: "Describe the decision in your own words — what you're weighing, and any context that matters. NomadFi will not pick a card or account on your behalf."
    )
    var scenarioText: String

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = scenarioText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            // Mirror CaptureDecisionDraftIntent's missing-scenario
            // dialog so the voice surface stays consistent.
            let dialog = DecisionAssistantIntentDialog.draftCaptureMissingScenario
            return .result(dialog: "\(dialog)")
        }

        // Route the launch to the Decision Assistant so the AI intake
        // sheet's host view actually mounts. Routes through the
        // App Group shared suite so the write is observable across
        // app + extension processes — same chokepoint
        // `OpenDecisionAssistantIntent` and `StartAIIntakeIntent`
        // use.
        DecisionsRoute.request()

        // Hand the pre-seeded scenario across via the value-typed
        // pending-request slot. `DecisionAssistantView` reads from
        // the same shared suite via `@AppStorage(_:store:)`,
        // consumes it once, and presents the AI intake sheet with
        // the scenario filled in.
        PendingAIIntakeRequestStore.write(
            PendingAIIntakeRequest(scenarioText: trimmed)
        )

        let dialog = DecisionAssistantIntentDialog.openAIIntakeAcknowledgement
        return .result(dialog: "\(dialog)")
    }
}
