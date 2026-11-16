import Foundation

/// How much time the spending breakdown covers at once: a month, a
/// rolling three months, or a calendar year. Which month or year is
/// chosen separately; see ``SpendingInterval``.
enum SpendingPeriod: String, CaseIterable, Identifiable, Sendable {
    case month
    case quarter
    case year

    var id: String { rawValue }

    /// Short name for the period picker.
    var title: LocalizedStringResource {
        switch self {
        case .month: "Month"
        case .quarter: "3 Months"
        case .year: "Year"
        }
    }

    /// How far one step back or forward moves.
    var step: (component: Calendar.Component, value: Int) {
        switch self {
        case .month: (.month, 1)
        case .quarter: (.month, 3)
        case .year: (.year, 1)
        }
    }
}
