// AccessibilitySettingsView.swift
// NomadFi
//
// Read-only accessibility page summarising what NomadFi already does
// out-of-the-box (VoiceOver-optimised narration, Dynamic Type across
// the app). There are no toggles here — accessibility is a baseline,
// not an opt-in — so the page is purely informative.

import SwiftUI

struct AccessibilitySettingsView: View {

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("VoiceOver Optimized")
                            .font(TypographyTokens.body)
                        Text("Every screen narrates as a coherent financial story.")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "accessibility")
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
                .accessibilityElement(children: .combine)

                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("Dynamic Type")
                            .font(TypographyTokens.body)
                        Text("All text scales to your preferred size, including the largest accessibility sizes.")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "textformat.size")
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
                .accessibilityElement(children: .combine)
            } footer: {
                Text("NomadFi is designed so the app is equally usable whether you rely on VoiceOver, larger text, or increased contrast. Adjust your preferences in the iOS Settings app.")
            }
        }
        .navigationTitle("Accessibility")
        .glassToolbar()
    }
}
