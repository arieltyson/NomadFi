// GlassCard.swift
// NomadFi
//
// A Liquid Glass-inspired card component using system materials.
// Adapts to Reduce Transparency for accessibility compliance.

import SwiftUI

/// A translucent card surface inspired by iOS 26's Liquid Glass aesthetic.
///
/// Uses `.ultraThinMaterial` for the glass effect, with an automatic
/// fallback to a solid surface when Reduce Transparency is enabled.
///
/// ```swift
/// GlassCard {
///     Text("Account Balance")
/// }
/// ```
struct GlassCard<Content: View>: View {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(SpacingTokens.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(.rect(cornerRadius: SpacingTokens.medium))
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            ColorTokens.surfaceSecondary
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(Color.teal.gradient)
            .ignoresSafeArea()

        VStack(spacing: SpacingTokens.medium) {
            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    Text("Global Net Worth")
                        .font(TypographyTokens.sectionHeader)
                    CurrencyText(
                        amount: 67_215.75,
                        currencyCode: .ttd,
                        font: TypographyTokens.amountLarge
                    )
                }
            }

            GlassCard {
                Text("Another card")
            }
        }
        .padding()
    }
}
