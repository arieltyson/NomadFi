import Foundation

/// The two ways the Spending screens draw parts of a whole.
enum SpendingChartStyle: String, CaseIterable, Sendable {
    /// A ring: shares at a glance.
    case wheel
    /// Horizontal bars: exact comparison between neighbors.
    case bars

    /// The style the toolbar button switches to.
    var toggled: SpendingChartStyle {
        self == .wheel ? .bars : .wheel
    }

    /// Names the button that switches to this style.
    var switchTitle: LocalizedStringResource {
        switch self {
        case .wheel: "Show as Wheel"
        case .bars: "Show as Bars"
        }
    }

    var systemImage: String {
        switch self {
        case .wheel: "chart.pie"
        case .bars: "chart.bar.xaxis"
        }
    }

    /// Where the choice is remembered between visits.
    static let storageKey = "spending.chartStyle"
}
