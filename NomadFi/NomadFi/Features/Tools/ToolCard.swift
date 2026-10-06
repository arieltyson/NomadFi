// ToolCard.swift
// NomadFi
//
// One tool on the Tools tab, as a tinted card.

import SwiftUI

/// A tool as a card: its symbol in its own colour above its name, on
/// a soft wash of that colour.
///
/// Radius, padding, wash strength and minimum height come from the
/// design system, so every card is the same shape and only the hue
/// tells them apart.
struct ToolCard: View {

    let tool: Tool

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ScaledMetric(relativeTo: .headline) private var minimumHeight = SizeTokens.tileMinimumHeight

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Image(systemName: tool.systemImage)
                .font(.title)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tool.tint)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(tool.title)
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.medium)
        // Fills its grid cell, so cards in a row share one height.
        .frame(maxWidth: .infinity, minHeight: minimumHeight, maxHeight: .infinity, alignment: .leading)
        .background(
            ColorTokens.tintedFill(tool.tint, contrast: colorSchemeContrast),
            in: .rect(cornerRadius: RadiusTokens.card, style: .continuous)
        )
        .overlay {
            if colorSchemeContrast == .increased {
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.increasedContrastOutline, lineWidth: 1)
            }
        }
        .contentShape(.rect(cornerRadius: RadiusTokens.card, style: .continuous))
    }
}

#Preview {
    ToolCard(tool: .exchangeRates)
        .padding()
}
