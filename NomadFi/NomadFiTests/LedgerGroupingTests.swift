import Foundation
import Testing
@testable import NomadFi

@MainActor
struct LedgerGroupingTests {

    private let calendar = Calendar.current
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        return calendar.date(byAdding: .hour, value: hour, to: calendar.date(byAdding: .day, value: -offset, to: base)!)!
    }
    private func purchase(_ name: String, on date: Date, category: TransactionCategory = .food) -> Transaction {
        Transaction(merchantName: name, originalAmount: 10, originalCurrency: .cad, date: date, category: category)
    }

    @Test func newestFirstInputGroupsByDayInOrder() {
        let rows = [purchase("a", on: day(0, hour: 18)), purchase("b", on: day(0, hour: 9)), purchase("c", on: day(1)), purchase("d", on: day(3))]
        let groups = LedgerViewModel().groupedByDate(rows)
        #expect(groups.map(\.transactions.count) == [2, 1, 1])
        #expect(groups.map(\.date) == groups.map(\.date).sorted(by: >))
        #expect(groups.first?.transactions.map(\.merchantName) == ["a", "b"])
    }

    @Test func unsortedInputStillYieldsOneGroupPerDayNewestFirst() {
        let rows = [purchase("c", on: day(1)), purchase("a", on: day(0)), purchase("d", on: day(1, hour: 8)), purchase("b", on: day(0, hour: 7))]
        let groups = LedgerViewModel().groupedByDate(rows)
        #expect(groups.count == 2)
        #expect(Set(groups.map(\.date)).count == 2)
        #expect(groups.map(\.date) == groups.map(\.date).sorted(by: >))
        #expect(groups.map(\.transactions.count) == [2, 2])
    }

    @Test func withNoFiltersTheListIsReturnedUnchanged() {
        let rows = [purchase("a", on: day(0)), purchase("b", on: day(1), category: .transport)]
        let model = LedgerViewModel()
        #expect(model.filteredTransactions(rows).map(\.merchantName) == ["a", "b"])
        model.selectedCategories = [.transport]
        #expect(model.filteredTransactions(rows).map(\.merchantName) == ["b"])
        model.selectedCategories = []
        model.searchText = "a"
        #expect(model.filteredTransactions(rows).map(\.merchantName) == ["a"])
    }
}
