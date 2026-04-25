// StartAIIntakeIntent.swift
// NomadFiWidgetExtension
//
// Widget-extension mirror of the main-app intent of the same
// name. Both copies declare the *same identifier* and the *same*
// body so iOS can dispatch the intent uniformly regardless of
// whether `perform()` ends up running in the widget process
// (background fallback) or the main app process (the
// `.foreground(.immediate)` happy path).
//
// Why two source files instead of one shared file:
//   Xcode 16's synchronized folder groups own each file by
//   exactly one default target. Cross-target membership requires
//   either a new shared folder (forbidden by this slice's "no
//   new top-level folders" rule) or per-file pbxproj exception
//   surgery. Two literal copies are the lowest-risk path; a
//   source-level test pins them in sync so they cannot drift.
//
// Why hardcoded UserDefaults key strings:
//   The widget extension is a separate compilation unit and
//   cannot reach `MainTabSelection.storageKey` or
//   `PendingAIIntakeRequest.storageKey` from the main app
//   target. Inlining the literal strings here, plus a test that
//   asserts they match the main-app constants, keeps both copies
//   honest without introducing a shared module.

import AppIntents
import Foundation

/// Widget-side mirror of `StartAIIntakeIntent`. See the main-app
/// copy under `NomadFi/Features/Intents/StartAIIntakeIntent.swift`
/// for the full design rationale; both files must declare the
/// same identifier and the same `perform()` semantics.
struct StartAIIntakeIntent: AppIntent {

    static let title: LocalizedStringResource = "Start Apple Intelligence Intake"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi to a blank on-device Apple Intelligence intake. NomadFi never analyzes or saves anything until you confirm in the app."
    )

    /// Foreground launch — brings the main app forward so its
    /// `perform()` body sees a fully-mounted Decisions tab and
    /// the existing one-shot routing consumer can present the
    /// AI intake sheet.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        // Mirror of `MainTabSelection.storageKey` — pinned by
        // `StartAIIntakeIntentTests.widgetCopyMatchesMainAppKeys`.
        let tabSelectionKey = "nomadfi.mainTab.selection"
        // Mirror of `MainTabSelection.decisions.rawValue` — pinned
        // by the same test.
        let decisionsTabRawValue = "decisions"
        // Mirror of `PendingAIIntakeRequest.storageKey` — pinned
        // by the same test.
        let pendingAIIntakeKey = "nomadfi.aiIntake.pendingRequest"
        // Mirror of `PendingAIIntakeRequest.blankLaunch.rawValue`
        // — `{"scenarioText":null}` is the JSON the main-app value
        // type emits for a blank-launch payload.
        let blankLaunchPayload = "{\"scenarioText\":null}"

        UserDefaults.standard.set(decisionsTabRawValue, forKey: tabSelectionKey)
        UserDefaults.standard.set(blankLaunchPayload, forKey: pendingAIIntakeKey)

        return .result()
    }
}
