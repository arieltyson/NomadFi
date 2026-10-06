// DraftCaptureControlWidget.swift
// NomadFiWidgetExtension
//
// `ControlWidget` that puts NomadFi's typed `DecisionDraftFormView`
// one tap away in Control Center, on the Lock Screen, and on the
// Action button — sibling to `AIIntakeControlWidget`. The control
// fires `StartDraftCaptureIntent`, which foregrounds NomadFi,
// switches to the Decisions tab, and presents the typed draft
// form ready for the user to fill in by hand.
//
// Why two control widgets, not one:
//   The two capture paths are semantically distinct — typed
//   manual capture vs. on-device AI intake — and Apple HIG
//   guidance for controls is to keep each control focused on a
//   single clear action. A combined "capture decision" control
//   that asked the user to choose a path on tap would be a
//   second-tap action, which is the opposite of what controls
//   are for. Two separate controls let the user pin whichever
//   path matches their preference (or both) to whichever
//   surface they actually use.
//
// Symbol vocabulary (deliberate visual distinction):
//   • `square.and.pencil` — typed manual capture. Out of
//     context in Control Center, a bare + would not say what it
//     adds; in the app the same action is the Decisions tab's +.
//   • `apple.intelligence` — AI intake (sibling control). The
//     two symbols make the path selection unmistakable at a
//     glance, with no reliance on color alone (HIG inclusivity
//     guidance).

import AppIntents
import SwiftUI
import WidgetKit

/// Control Widget that launches NomadFi's typed draft capture
/// form from any system surface that hosts controls.
struct DraftCaptureControlWidget: ControlWidget {

    /// Stable identifier for the control. Reverse-DNS namespaced
    /// under the app bundle so it cannot collide with system or
    /// third-party controls.
    static let kind: String = "com.nomadfi.app.controls.draftCapture"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: DraftCaptureControlValueProvider()
        ) { _ in
            ControlWidgetButton(action: StartDraftCaptureIntent()) {
                Label(
                    "Start Draft",
                    systemImage: "square.and.pencil"
                )
            }
        }
        .displayName("Start Draft")
        .description("Open NomadFi to a blank typed decision draft. Nothing saves until you confirm in the app.")
    }
}

/// Pure value provider for the control. Static controls require
/// a `ControlValueProvider` even when no per-instance state is
/// needed; this provider returns a single sentinel value because
/// the control's appearance never depends on user data.
private struct DraftCaptureControlValueProvider: ControlValueProvider {

    var previewValue: Bool { false }

    func currentValue() async throws -> Bool { false }
}
