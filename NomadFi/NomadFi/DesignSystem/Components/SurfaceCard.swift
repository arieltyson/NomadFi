// SurfaceCard.swift
// NomadFi
//
// The app's one content container.

import SwiftUI

/// The app's one container shape.
///
/// Everything that groups content sits in one of these, so surface,
/// radius and inset are decided once. A solid adaptive surface rather
/// than a material: per the HIG, Liquid Glass and translucency belong
/// to the navigation layer floating above content, not to content
/// itself. A solid fill also needs no blur pass, so long scrolling
/// stacks of cards stay cheap to render.
///
/// ```swift
/// SurfaceCard {
///     Text("Account Balance")
/// }
/// ```
struct SurfaceCard<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(SpacingTokens.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ColorTokens.surfaceSecondary,
                in: .rect(cornerRadius: RadiusTokens.card, style: .continuous)
            )
    }
}

#Preview {
    VStack(spacing: SpacingTokens.medium) {
        SurfaceCard {
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

        SurfaceCard {
            Text("Another card")
        }
    }
    .padding()
}
