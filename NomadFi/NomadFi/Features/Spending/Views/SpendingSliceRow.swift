import SwiftUI

/// One slice of a Spending chart as a row: its icon in the slice's color,
/// its name and share, and its amount.
struct SpendingSliceRow: View {

    /// What sits at the row's trailing edge.
    enum Accessory {
        /// The row opens another screen.
        case navigates
        /// The row shows or hides what is inside it.
        case expands(isExpanded: Bool)
    }

    let slice: SpendingChartSlice
    let currency: CurrencyCode
    let accessory: Accessory
    var isHighlighted = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.xxSmall))
            : AnyLayout(HStackLayout(spacing: SpacingTokens.small))

        layout {
            TintedIconBadge(systemImage: slice.systemImage, tint: ColorTokens.chartColor(at: slice.colorRank))

            VStack(alignment: .leading, spacing: SpacingTokens.xxxSmall) {
                Text(slice.name)
                    .font(TypographyTokens.body)
                Text(slice.share, format: .percent.precision(.fractionLength(0)))
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: SpacingTokens.xSmall)
            }

            HStack(spacing: SpacingTokens.xSmall) {
                CurrencyText(amount: slice.total, currencyCode: currency)
                SpendingRowAccessory(accessory: accessory)
            }
        }
        .padding(.vertical, SpacingTokens.xSmall)
        .padding(.horizontal, SpacingTokens.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHighlighted ? ColorTokens.selectedRowBackground(for: contrast) : .clear,
            in: .rect(cornerRadius: RadiusTokens.medium, style: .continuous)
        )
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

/// The chevron at a ``SpendingSliceRow``'s trailing edge.
private struct SpendingRowAccessory: View {

    let accessory: SpendingSliceRow.Accessory

    var body: some View {
        switch accessory {
        case .navigates:
            Image(systemName: "chevron.forward")
                .font(TypographyTokens.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .expands(let isExpanded):
            Image(systemName: "chevron.down")
                .font(TypographyTokens.caption.bold())
                .foregroundStyle(.tertiary)
                .rotationEffect(isExpanded ? .zero : .degrees(-90))
                .accessibilityHidden(true)
        }
    }
}
