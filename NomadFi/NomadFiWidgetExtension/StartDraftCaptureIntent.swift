// StartDraftCaptureIntent.swift
// NomadFiWidgetExtension
//
// Widget-extension mirror of the main-app intent of the same
// name. Both copies declare the *same identifier* and the *same*
// body so iOS can dispatch the intent uniformly regardless of
// which process runs `perform()`.
//
// Why two source files instead of one shared file:
//   Same rationale as `StartAIIntakeIntent`'s mirror — Xcode
//   16's synchronized folder groups own each file by exactly
//   one default target. Two literal copies are the lowest-risk
//   path; a source-level test pins them in sync.
//
// Why the App Group shared suite:
//   `UserDefaults.standard` is the *current process's*
//   defaults. The widget extension's process and the main app's
//   process see different `.standard` stores, so a write through
//   `.standard` from the widget would be invisible to the
//   main-app `@AppStorage` consumer. Routing through the App
//   Group suite via `NomadFiWidgetSharedConstants.appGroupIdentifier`
//   is the only correct cross-process channel.

import AppIntents
import Foundation
import OSLog

/// Widget-side mirror of `StartDraftCaptureIntent`. See the
/// main-app copy for the full design rationale; both files must
/// declare the same identifier and the same `perform()`
/// semantics.
struct StartDraftCaptureIntent: AppIntent {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "StartDraftCaptureIntent.widget"
    )

    static let title: LocalizedStringResource = "Start Draft Capture"

    static let description: IntentDescription = IntentDescription(
        "Open NomadFi to a blank typed decision draft. NomadFi never saves anything until you confirm in the app."
    )

    /// Foreground launch — brings the main app forward so its
    /// `perform()` body sees a fully-mounted Decisions tab and
    /// the existing one-shot routing consumer can present the
    /// typed draft form.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        // Mirror of `MainTabSelection.storageKey` — pinned by
        // `StartDraftCaptureIntentTests.widgetCopyMatchesMainAppKeys`.
        let tabSelectionKey = "nomadfi.mainTab.selection"
        // Mirror of `MainTabSelection.decisions.rawValue` — pinned
        // by the same test.
        let decisionsTabRawValue = "decisions"
        // Mirror of `PendingDraftCaptureFlag.storageKey` — pinned
        // by the same test.
        let pendingDraftKey = "nomadfi.draftCapture.pendingRequest"

        // Resolve the App Group shared suite via the existing
        // mirrored constant. If unavailable the App Groups
        // capability is misconfigured on the widget extension —
        // log a fault and skip the writes; the user's tap is a
        // no-op (loud signal, not a silent fall-back to the
        // widget's own `.standard` defaults that the main app
        // never reads).
        guard let defaults = UserDefaults(
            suiteName: NomadFiWidgetSharedConstants.appGroupIdentifier
        ) else {
            Self.logger.fault(
                "App Group suite '\(NomadFiWidgetSharedConstants.appGroupIdentifier, privacy: .public)' is unavailable from the widget extension. The control tap will not route the launch."
            )
            return .result()
        }

        defaults.set(decisionsTabRawValue, forKey: tabSelectionKey)
        defaults.set(true, forKey: pendingDraftKey)

        return .result()
    }
}
