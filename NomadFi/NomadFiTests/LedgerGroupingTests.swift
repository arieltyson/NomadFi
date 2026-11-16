import Foundation
import SwiftData
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
        let groups = LedgerViewModel.groupedByDate(rows)
        #expect(groups.map(\.transactions.count) == [2, 1, 1])
        #expect(groups.map(\.date) == groups.map(\.date).sorted(by: >))
        #expect(groups.first?.transactions.map(\.merchantName) == ["a", "b"])
    }

    @Test func unsortedInputStillYieldsOneGroupPerDayNewestFirst() {
        let rows = [purchase("c", on: day(1)), purchase("a", on: day(0)), purchase("d", on: day(1, hour: 8)), purchase("b", on: day(0, hour: 7))]
        let groups = LedgerViewModel.groupedByDate(rows)
        #expect(groups.count == 2)
        #expect(Set(groups.map(\.date)).count == 2)
        #expect(groups.map(\.date) == groups.map(\.date).sorted(by: >))
        #expect(groups.map(\.transactions.count) == [2, 2])
    }

    @Test func filtersBecomeOneStorePredicate() async throws {
        let rows = [purchase("a", on: day(0)), purchase("b", on: day(1), category: .transport)]
        let model = LedgerViewModel()
        #expect(model.filterPredicate == nil)

        model.selectedCategories = [.transport]
        #expect(try matches(model, rows) == ["b"])

        model.selectedCategories = []
        model.searchText = "a"
        await model.applySearchText()
        #expect(try matches(model, rows) == ["a"])
    }

    @Test func pagingGrowsOnlyWhenThePageIsFullAndResetsOnNewFilters() {
        let model = LedgerViewModel()
        model.loadNextPage(loadedCount: LedgerViewModel.pageSize - 1)
        #expect(model.fetchLimit == LedgerViewModel.pageSize)

        model.loadNextPage(loadedCount: LedgerViewModel.pageSize)
        #expect(model.fetchLimit == LedgerViewModel.pageSize * 2)

        model.selectedJurisdiction = "CA"
        #expect(model.fetchLimit == LedgerViewModel.pageSize)
    }

    @Test func theStoreRunsTheCombinedFilterAndPageLimit() async throws {
        let container = try ModelContainer(
            for: Transaction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        for offset in 0...LedgerViewModel.pageSize {
            context.insert(purchase("Cafe \(offset)", on: day(offset), category: .transport))
        }
        context.insert(purchase("Cafe Other", on: day(0), category: .food))

        let model = LedgerViewModel()
        #expect(try context.fetch(model.fetchDescriptor).count == LedgerViewModel.pageSize)

        model.selectedCategories = [.transport]
        model.searchText = "cafe 1"
        await model.applySearchText()
        let names = try context.fetch(model.fetchDescriptor).map(\.merchantName)
        #expect(!names.isEmpty)
        #expect(names.allSatisfy { $0.hasPrefix("Cafe 1") })
    }

    private func matches(_ model: LedgerViewModel, _ rows: [Transaction]) throws -> [String] {
        let predicate = try #require(model.filterPredicate)
        return try rows.filter { try predicate.evaluate($0) }.map(\.merchantName)
    }
}
