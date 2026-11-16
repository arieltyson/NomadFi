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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                SpendingSliceRowContent(slice: slice, currency: currency, accessory: accessory, isStacked: true)
            } else {
                // One line when the name and amount fit side by side;
                // otherwise the amount moves under the name, so neither
                // a name nor an amount is ever broken mid-word.
                ViewThatFits(in: .horizontal) {
                    SpendingSliceRowContent(slice: slice, currency: currency, accessory: accessory, isStacked: false)
                    SpendingSliceRowContent(slice: slice, currency: currency, accessory: accessory, isStacked: true)
                }
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

/// A ``SpendingSliceRow``'s icon, name, share, amount and chevron, either
/// side by side or with the amount under the name.
private struct SpendingSliceRowContent: View {

    let slice: SpendingChartSlice
    let currency: CurrencyCode
    let accessory: SpendingSliceRow.Accessory
    let isStacked: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            TintedIconBadge(systemImage: slice.systemImage, tint: ColorTokens.chartColor(at: slice.colorRank))

            VStack(alignment: .leading, spacing: SpacingTokens.xxxSmall) {
                Text(slice.name)
                    .font(TypographyTokens.body)
                    .lineLimit(isStacked ? nil : 1)
                    .fixedSize(horizontal: !isStacked, vertical: isStacked)
                if isStacked {
                    CurrencyText(amount: slice.total, currencyCode: currency)
                }
                Text(slice.share, format: .percent.precision(.fractionLength(0)))
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: SpacingTokens.xSmall)

            if !isStacked {
                CurrencyText(amount: slice.total, currencyCode: currency)
                    .lineLimit(1)
                    .fixedSize()
            }
            SpendingRowAccessory(accessory: accessory)
        }
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
