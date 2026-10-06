// TileCard.swift
// NomadFi
//
// One destination as a tinted card.

import SwiftUI

/// A destination as a card: its symbol in its own colour above its
/// name, on a soft wash of that colour.
///
/// Radius, padding, wash strength and minimum height come from the
/// design system, so every card is the same shape and only the hue
/// tells them apart.
struct TileCard<Item: TileItem>: View {

    let item: Item

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var minimumHeight = SizeTokens.tileMinimumHeight

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Image(systemName: item.systemImage)
                .font(.title)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(item.tint)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(item.title)
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.medium)
        // Fills its grid cell, so cards in a row share one height. At
        // accessibility sizes the grid is one column, so there is no
        // row to match and the card fits its content instead.
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : minimumHeight,
            maxHeight: .infinity,
            alignment: .leading
        )
        .background(
            ColorTokens.tintedFill(item.tint, contrast: colorSchemeContrast),
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
