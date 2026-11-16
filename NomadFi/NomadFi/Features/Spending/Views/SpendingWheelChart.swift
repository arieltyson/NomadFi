import Charts
import SwiftUI

/// A ring of slices with the total, or the touched slice, in its hole.
struct SpendingWheelChart: View {

    let slices: [SpendingChartSlice]
    let total: Double
    let currency: CurrencyCode
    let caption: String
    @Binding var selectedID: String?

    @State private var angleSelection: Double?

    var body: some View {
        let selected = slices.first { $0.id == selectedID }
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.total),
                innerRadius: .ratio(SizeTokens.ringChartInnerRadiusRatio),
                angularInset: SizeTokens.ringChartSectorInset
            )
            .cornerRadius(RadiusTokens.small)
            .foregroundStyle(ColorTokens.chartColor(at: slice.colorRank))
            .opacity(selectedID == nil || selectedID == slice.id ? 1 : ColorTokens.chartDimmedOpacity)
            .accessibilityLabel(slice.name)
            .accessibilityValue(MoneyFormatStyle.spokenAmount(slice.total, code: currency.rawValue))
        }
        .chartAngleSelection(value: $angleSelection)
        .chartBackground { _ in
            SpendingChartHeadline(
                title: selected?.name ?? caption,
                amount: selected?.total ?? total,
                currency: currency
            )
            .padding(SpacingTokens.xxLarge)
        }
        .frame(maxWidth: SizeTokens.ringChartMaxDiameter)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .onChange(of: angleSelection) { _, value in
            selectedID = value.flatMap { SpendingViewModel.sliceID(atAngleValue: $0, in: slices) }
        }
    }
}
