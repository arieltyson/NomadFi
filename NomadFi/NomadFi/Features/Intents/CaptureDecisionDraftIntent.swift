// CaptureDecisionDraftIntent.swift
// NomadFi
//
// Siri / App Shortcut: "Capture a decision in NomadFi."
// Takes a user-dictated scenario and optional structured context
// (title, kind, merchant, location, timing, notes) and saves a
// ``DecisionDraftRecord`` to the on-device store with status
// ``DecisionDraftStatus/needsEngine``.
//
// Intentionally conservative:
//   - `supportedModes = .background` — the intent never opens the
//     app on capture. Users can open NomadFi later to review their
//     captured drafts in the Decisions tab.
//   - No analysis, no scoring, no recommendation. The dialog says so
//     explicitly via `DecisionAssistantIntentDialog.draftCaptureSuccess`.
//   - Amount and currency are deliberately omitted. Voice dictation
//     of decimal amounts across locales is error-prone, and the
//     financial-rigour mission refuses to silently guess a currency.
//     Users who need amount context can add it by editing the draft
//     in-app.

import AppIntents
import SwiftData

/// Captures a user's decision scenario as a local-only draft.
///
/// This is NomadFi's first voice intake channel. It can run entirely
/// in the background and never surfaces a recommendation — the
/// deterministic engine catalog stays untouched.
struct CaptureDecisionDraftIntent: AppIntent {

    static let title: LocalizedStringResource = "Capture Decision Draft"

    static let description: IntentDescription = IntentDescription(
        "Save a decision you're weighing as a private, on-device draft. NomadFi will not analyze or recommend anything from it until a deterministic engine covers this kind of decision."
    )

    /// Voice-only capture — no app activation required.
    static let supportedModes: IntentModes = .background

    // MARK: - Parameters

    @Parameter(
        title: "Scenario",
        description: "Describe the decision in your own words — what you're weighing, and any context that matters."
    )
    var scenarioText: String

    @Parameter(
        title: "Title",
        description: "Optional short title that will help you recognise this draft later."
    )
    var draftTitle: String?

    @Parameter(
        title: "Decision kind",
        description: "Optional category for this decision."
    )
    var kind: DecisionDraftKindAppEnum?

    @Parameter(
        title: "Merchant or counterparty",
        description: "Optional — who the money is going to or coming from."
    )
    var merchantName: String?

    @Parameter(
        title: "Location",
        description: "Optional short city or context hint. Do not enter a full address."
    )
    var locationText: String?

    @Parameter(
        title: "Timing",
        description: "Optional — when the decision needs to be made, in your own words."
    )
    var timingText: String?

    @Parameter(
        title: "Notes",
        description: "Optional extra notes."
    )
    var notes: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = scenarioText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            let dialog = DecisionAssistantIntentDialog.draftCaptureMissingScenario
            return .result(dialog: "\(dialog)")
        }

        let container = try ModelContainer(for: DecisionDraftRecord.self)
        let context = container.mainContext

        let inserted = DecisionDraftStore.insertDraft(
            scenarioText: trimmed,
            title: draftTitle ?? "",
            kind: kind?.draftKind ?? .purchase,
            merchantName: merchantName ?? "",
            locationText: locationText ?? "",
            timingText: timingText ?? "",
            notes: notes ?? "",
            in: context
        )

        guard let inserted else {
            // Store refused the insert (only possible on empty text,
            // which we already guarded above). Return the same
            // missing-scenario dialog so the user sees a coherent
            // message rather than silence.
            let dialog = DecisionAssistantIntentDialog.draftCaptureMissingScenario
            return .result(dialog: "\(dialog)")
        }

        let dialog = DecisionAssistantIntentDialog.draftCaptureSuccess(
            title: inserted.title
        )
        return .result(dialog: "\(dialog)")
    }
}
