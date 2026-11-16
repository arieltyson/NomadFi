import Charts
import SwiftUI

/// One bar per slice, longest first, for comparing neighbors exactly.
struct SpendingBarChart: View {

    let slices: [SpendingChartSlice]
    let total: Double
    let currency: CurrencyCode
    let caption: String
    @Binding var selectedID: String?

    @State private var nameSelection: String?
    /// One comfortable touch target per bar plus its name above it,
    /// growing with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var barRowHeight = SizeTokens.minimumTapTarget + SpacingTokens.small

    var body: some View {
        let selected = slices.first { $0.id == selectedID }
        VStack(spacing: SpacingTokens.small) {
            SpendingChartHeadline(
                title: selected?.name ?? caption,
                amount: selected?.total ?? total,
                currency: currency
            )
            Chart(slices) { slice in
                BarMark(
                    x: .value("Amount", slice.total),
                    y: .value("Kind", slice.name),
                    height: .ratio(SizeTokens.barChartBarHeightRatio)
                )
                .cornerRadius(RadiusTokens.small)
                .foregroundStyle(ColorTokens.chartColor(at: slice.colorRank))
                .opacity(selectedID == nil || selectedID == slice.id ? 1 : ColorTokens.chartDimmedOpacity)
                .annotation(position: .top, alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(slice.name)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                .annotation(position: .trailing) {
                    Text(slice.share, format: .percent.precision(.fractionLength(0)))
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(slice.name)
                .accessibilityValue(MoneyFormatStyle.spokenAmount(slice.total, code: currency.rawValue))
            }
            .chartXAxis(.hidden)
            // Each bar carries its own name, so it never reads as the
            // neighbor's.
            .chartYAxis(.hidden)
            .chartYSelection(value: $nameSelection)
            .frame(height: CGFloat(slices.count) * barRowHeight)
        }
        .onChange(of: nameSelection) { _, name in
            selectedID = name.flatMap { name in slices.first { $0.name == name }?.id }
        }
    }
}
