import SwiftUI

/// Draws parts of a whole as a wheel or as bars, as the person prefers.
struct SpendingChart: View {

    let slices: [SpendingChartSlice]
    let total: Double
    let currency: CurrencyCode
    /// What the whole is called when nothing is touched, such as "3 Months".
    let caption: String
    let style: SpendingChartStyle
    @Binding var selectedID: String?

    var body: some View {
        switch style {
        case .wheel:
            SpendingWheelChart(slices: slices, total: total, currency: currency, caption: caption, selectedID: $selectedID)
                .transition(.opacity)
        case .bars:
            SpendingBarChart(slices: slices, total: total, currency: currency, caption: caption, selectedID: $selectedID)
                .transition(.opacity)
        }
    }
}
