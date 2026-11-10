// AskFiBotBackground.swift
// NomadFi
//
// The soft brand wash behind Ask FiBot.

import SwiftUI

/// A still wash of the brand colour that fades into the system
/// background, so the screen feels like FiBot's own without competing
/// with the words on it. It never animates, so it costs nothing at rest.
struct AskFiBotBackground: View {

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        LinearGradient(
            colors: [
                ColorTokens.tintedFill(ColorTokens.brandPrimary, contrast: contrast),
                ColorTokens.tintedSurface(ColorTokens.brandSecondary, contrast: contrast),
                ColorTokens.surfacePrimary,
            ],
            startPoint: .top,
            endPoint: .center
        )
        .background(ColorTokens.surfacePrimary)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
