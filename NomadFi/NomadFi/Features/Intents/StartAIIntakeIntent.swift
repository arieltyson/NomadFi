// StartAIIntakeIntent.swift
// NomadFi
//
// Parameterless, foreground-launching App Intent specifically
// designed for one-tap system surfaces — Control Center,
// Lock Screen, and the Action button (via the
// `AIIntakeControlWidget` `ControlWidgetButton`). Routes the
// launch to the Decisions tab and asks the in-app
// `DecisionAIIntakeSheet` to present *blank*; the user starts
// typing their scenario directly into the on-device AI intake
// flow, then proceeds through the existing bounded clarification
// + review + explicit-save sequence.
//
// Why a separate intent instead of reusing `OpenAIIntakeIntent`:
//   `OpenAIIntakeIntent` declares a required `scenarioText: String`
//   parameter so Siri / Shortcuts can pre-seed dictated text.
//   That parameter is exactly what makes the intent *wrong* for a
//   one-tap control: tapping a `ControlWidgetButton` would surface
//   Apple's parameter-summary UI demanding text up front, which
//   defeats "one tap into the intake flow". This intent is the
//   parameterless sibling — same destination, no friction.
//
// Why `.foreground(.immediate)`:
//   The user's purpose is to *use* the intake flow inside NomadFi
//   — read clarifying questions, edit fields, decide what to
//   save. `.foreground(.immediate)` is the iOS 18+ replacement
//   for `openAppWhenRun = true` and the only mode that lets the
//   Decisions tab mount before `perform()` returns, so the AI
//   sheet appears the moment the app comes forward.
//
// Why this file is duplicated in the widget extension:
//   `ControlWidgetButton(action: StartAIIntakeIntent())` requires
//   the widget extension's compilation unit to *see* the intent
//   type. `.foreground(.immediate)` then dispatches `perform()`
//   in the *main app* process, which requires the same intent
//   identifier to be registered in the main app's App Intents
//   metadata. The cleanest pattern under Xcode 16's synchronized
//   folders is to define the intent in both targets with
//   identical identifiers and bodies; a source-level test
//   (`StartAIIntakeIntentTests.intentBodiesStayInSync`) pins the
//   two copies so they cannot drift.
//
// Honesty contract preserved end-to-end:
//   AI structures input. User confirms. Deterministic engines
//   decide later. The intent itself never interprets, never
//   saves, never recommends — it only navigates and writes a
//   blank-launch payload to the existing one-shot routing slot.

import AppIntents
import Foundation

/// Opens NomadFi on the Decisions tab and presents the on-device
/// AI intake sheet with an empty scenario field. Built for
/// one-tap launch from Control Center, the Lock Screen, and the
/// Action button via the `AIIntakeControlWidget`
/// `ControlWidgetButton`.
struct StartAIIntakeIntent: AppIntent {

    static let title: LocalizedStringResource = "Start Apple Intelligence Intake"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi to a blank on-device Apple Intelligence intake. NomadFi never analyzes or saves anything until you confirm in the app."
    )

    /// Foreground launch — same mode `OpenAIIntakeIntent` uses for
    /// the Siri / Shortcut path. Brings the app to the foreground
    /// before `perform()` runs so the Decisions tab can mount and
    /// observe the routing slot.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        // Route the launch to the Decisions tab so the AI intake
        // sheet's host view actually mounts. Same `@AppStorage`
        // chokepoint `OpenDecisionAssistantIntent` and
        // `OpenAIIntakeIntent` use.
        UserDefaults.standard.set(
            MainTabSelection.decisions.rawValue,
            forKey: MainTabSelection.storageKey
        )

        // Hand a blank-launch payload across via the value-typed
        // pending-request slot. `DecisionAssistantView` reads from
        // the slot via `@AppStorage`, consumes it once, and
        // presents the AI intake sheet with an empty scenario
        // field ready for typing.
        PendingAIIntakeRequestStore.write(.blankLaunch)

        return .result()
    }
}
