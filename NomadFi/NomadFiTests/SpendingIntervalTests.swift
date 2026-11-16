import Foundation
import Testing
@testable import NomadFi

@MainActor
struct SpendingIntervalTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func threeMonthsEndWithTheChosenMonthAndStepByThree() {
        let november = SpendingInterval(.quarter, containing: date(2026, 11), calendar: calendar)
        #expect(november.start == date(2026, 9, 1))
        #expect(november.end == date(2026, 12, 1))

        let earlier = november.shifted(by: -1, calendar: calendar)
        #expect(earlier.start == date(2026, 6, 1))
        #expect(earlier.end == date(2026, 9, 1))

        let acrossYears = SpendingInterval(.quarter, containing: date(2026, 1), calendar: calendar)
        #expect(acrossYears.start == date(2025, 11, 1))
    }

    @Test func monthsAndYearsAreCalendarMonthsAndYears() {
        let february = SpendingInterval(.month, containing: date(2025, 2), calendar: calendar)
        #expect(february.start == date(2025, 2, 1))
        #expect(february.shifted(by: 1, calendar: calendar).start == date(2025, 3, 1))

        let year = SpendingInterval(.year, containing: date(2025, 2), calendar: calendar)
        #expect(year.start == date(2025, 1, 1))
        #expect(year.end == date(2026, 1, 1))
        #expect(year.shifted(by: -1, calendar: calendar).start == date(2024, 1, 1))
    }

    @Test func switchingToYearKeepsTheChosenMonthsYear() {
        let viewModel = SpendingViewModel(homeCurrency: .cad)
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        viewModel.show(SpendingInterval(.month, containing: lastYear))
        viewModel.period = .year
        #expect(viewModel.interval == SpendingInterval(.year, containing: lastYear))
        #expect(viewModel.canGoForward())
    }
}
