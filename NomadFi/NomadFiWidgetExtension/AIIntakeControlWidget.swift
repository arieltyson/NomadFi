// AIIntakeControlWidget.swift
// NomadFiWidgetExtension
//
// `ControlWidget` that puts NomadFi's on-device Apple Intelligence
// intake one tap away in Control Center, on the Lock Screen, and
// on the Action button. The control fires
// `StartAIIntakeIntent`, which foregrounds NomadFi, switches to
// the Decisions tab, and presents `DecisionAIIntakeSheet` with an
// empty scenario field — the user starts typing immediately and
// then proceeds through the existing bounded clarification +
// review + explicit-save flow.
//
// HIG references:
//   • Controls — https://developer.apple.com/design/human-interface-guidelines/controls
//   • WidgetKit Controls collection —
//     https://developer.apple.com/documentation/widgetkit/controls-collection
//   • ControlWidgetButton —
//     https://developer.apple.com/documentation/widgetkit/controlwidgetbutton
//
// Design choices:
//   • `StaticControlConfiguration` — no per-instance configuration
//     UI. The control does exactly one thing; a configuration step
//     would add friction without value. (Apple HIG: prefer
//     unconfigurable controls when there's a single clear action.)
//   • `ControlWidgetButton` over `Toggle` — the action *opens an
//     in-app surface*; it doesn't toggle persistent state.
//   • `apple.intelligence` SF Symbol — same glyph as the
//     "Describe with Apple Intelligence" item in the Decisions
//     tab's + menu, so the control reads as the same affordance
//     across surfaces.
//   • `displayName` and `description` are explicit and concise per
//     HIG ("clear, action-first labelling for controls").

import AppIntents
import SwiftUI
import WidgetKit

/// Control Widget that launches NomadFi's blank on-device AI
/// intake from any system surface that hosts controls.
struct AIIntakeControlWidget: ControlWidget {

    /// Stable identifier for the control. Reverse-DNS namespaced
    /// under the app bundle so it cannot collide with system or
    /// third-party controls.
    static let kind: String = "com.nomadfi.app.controls.aiIntake"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: AIIntakeControlValueProvider()
        ) { _ in
            ControlWidgetButton(action: StartAIIntakeIntent()) {
                Label(
                    "Capture with Apple Intelligence",
                    systemImage: "apple.intelligence"
                )
            }
        }
        .displayName("AI Intake")
        .description("Capture a decision with on-device Apple Intelligence. NomadFi will not analyze or save anything until you confirm in the app.")
    }
}

/// Pure value provider for the control. Static controls still
/// require a `ControlValueProvider` even when no per-instance
/// state is needed; this provider returns a single sentinel value
/// because the control's appearance never depends on user data.
private struct AIIntakeControlValueProvider: ControlValueProvider {

    /// `Void`-shaped placeholder. The control's label is hard-
    /// coded at the `ControlWidgetButton` site, so the provided
    /// value is never read by the configuration body.
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool { false }
}
