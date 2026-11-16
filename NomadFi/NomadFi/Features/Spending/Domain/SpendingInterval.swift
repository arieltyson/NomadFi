import Foundation

/// The exact stretch of time a spending breakdown covers: a calendar
/// month, three months ending with a chosen month, or a calendar year.
struct SpendingInterval: Hashable, Identifiable, Sendable {

    let period: SpendingPeriod
    /// The first instant covered.
    let start: Date
    /// The first instant after the interval.
    let end: Date

    var id: Self { self }

    /// The interval of the given length that holds `date`. Three months
    /// end with `date`'s month.
    init(_ period: SpendingPeriod, containing date: Date, calendar: Calendar = .current) {
        self.period = period
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        switch period {
        case .month:
            start = month.start
            end = month.end
        case .quarter:
            end = month.end
            start = calendar.date(byAdding: .month, value: -2, to: month.start) ?? month.start
        case .year:
            let year = calendar.dateInterval(of: .year, for: date) ?? month
            start = year.start
            end = year.end
        }
    }

    /// A date inside the interval's last month, which a period change
    /// keeps, so switching from a month to its year stays in that year.
    var lastMonthDate: Date {
        end.addingTimeInterval(-1)
    }

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }

    /// The interval `steps` lengths away: earlier when negative.
    func shifted(by steps: Int, calendar: Calendar = .current) -> SpendingInterval {
        let (component, value) = period.step
        let moved = calendar.date(byAdding: component, value: value * steps, to: lastMonthDate) ?? lastMonthDate
        return SpendingInterval(period, containing: moved, calendar: calendar)
    }

    /// What the interval is called: "November 2026", "Sep – Nov 2026" or
    /// "2026", in the person's locale.
    var title: String {
        switch period {
        case .month:
            start.formatted(.dateTime.month(.wide).year())
        case .quarter:
            (start..<lastMonthDate).formatted(.interval.month(.abbreviated).year())
        case .year:
            start.formatted(.dateTime.year())
        }
    }
}
