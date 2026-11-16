import Foundation

/// How far back the spending breakdown looks, always in whole months
/// ending with the current one.
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

    /// How many months the period covers, including the current one.
    var monthCount: Int {
        switch self {
        case .month: 1
        case .quarter: 3
        case .year: 12
        }
    }

    /// The first instant the period covers: the start of its first month.
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date {
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return calendar.date(byAdding: .month, value: -(monthCount - 1), to: thisMonth) ?? thisMonth
    }
}
