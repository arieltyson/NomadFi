// StartDraftCaptureIntent.swift
// NomadFi
//
// Parameterless, foreground-launching App Intent specifically
// designed for one-tap system surfaces (Control Center, Lock
// Screen, Action button, App Shortcuts) that should land the
// user directly on the *typed* draft form. Sibling to
// `StartAIIntakeIntent` — same shape, same one-shot routing,
// different in-app destination.
//
// Why a separate intent from `CaptureDecisionDraftIntent`:
//   `CaptureDecisionDraftIntent` is the background Siri intent
//   that takes dictated parameters (scenario, kind, merchant…)
//   and *saves* a draft to the on-device store directly. That's
//   the right shape for "Hey Siri, capture this decision …" but
//   completely wrong for a one-tap control: the control launch
//   needs to *open* the typed form so the user can fill it in
//   themselves, with no pre-launch persistence.
//
// Why `.foreground(.immediate)`:
//   The user's purpose is to *use* the typed form inside
//   NomadFi. `.foreground(.immediate)` is the iOS 18+
//   replacement for `openAppWhenRun = true` and the only mode
//   that lets the Decisions tab mount before `perform()`
//   returns, so the form sheet appears the moment the app comes
//   forward.
//
// Why this file is duplicated in the widget extension:
//   `ControlWidgetButton(action: StartDraftCaptureIntent())`
//   requires the widget extension's compilation unit to *see*
//   the intent type. `.foreground(.immediate)` then dispatches
//   `perform()` in the *main app* process, which requires the
//   same intent identifier to be registered in the main app's
//   App Intents metadata. The cleanest pattern under Xcode 16's
//   synchronized folders is to define the intent in both
//   targets with identical identifiers and bodies; a source-
//   level test pins the two copies so they cannot drift.
//
// Honesty contract:
//   The intent is *navigation only* — it sets the routing slot
//   and the typed-form launch flag, then returns. No
//   persistence, no interpretation, no recommendation, no
//   ranking. The form's existing Save button remains the only
//   write path.

import AppIntents
import Foundation

/// Opens NomadFi on the Decisions tab and presents the typed
/// `DecisionDraftFormView`. Sibling to `StartAIIntakeIntent` —
/// same one-shot routing, different in-app destination.
struct StartDraftCaptureIntent: AppIntent {

    static let title: LocalizedStringResource = "Start Draft Capture"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi to a blank typed decision draft. NomadFi never saves anything until you confirm in the app."
    )

    /// Foreground launch — same mode `StartAIIntakeIntent` and
    /// the other foreground routing intents use.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        // Route the launch to the Decisions tab so the typed
        // draft form's host view actually mounts. Routes through
        // the App Group shared suite — same `AppRoutingDefaults`
        // chokepoint every other foreground routing intent uses.
        AppRoutingDefaults.shared.set(
            MainTabSelection.decisions.rawValue,
            forKey: MainTabSelection.storageKey
        )

        // Hand the typed-form launch request across via the
        // value-typed pending-draft-capture flag.
        // `DecisionAssistantView` reads from the same shared
        // suite via `@AppStorage(_:store:)`, consumes the flag
        // once, and presents the typed `DecisionDraftFormView`.
        PendingDraftCaptureFlag.write()

        return .result()
    }
}
