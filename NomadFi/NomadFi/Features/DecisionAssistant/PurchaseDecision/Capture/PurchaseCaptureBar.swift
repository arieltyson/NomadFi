// PurchaseCaptureBar.swift
// NomadFi
//
// Two quick ways to say where you are paying.

import SwiftUI

/// Near Me and Say It: fill in the purchase from where the person is, or
/// from what they say, instead of typing at the till.
struct PurchaseCaptureBar: View {

    let onNearMe: () -> Void
    let onSayIt: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                Button("Near Me", systemImage: "location.fill", action: onNearMe)
                    .accessibilityHint("Lists places around you to fill in the purchase")
                Button("Say It", systemImage: "mic.fill", action: onSayIt)
                    .accessibilityHint("Fills in the purchase from what you say")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .buttonSizing(.flexible)
        }
    }
}

#Preview {
    PurchaseCaptureBar(onNearMe: {}, onSayIt: {})
        .padding()
}
