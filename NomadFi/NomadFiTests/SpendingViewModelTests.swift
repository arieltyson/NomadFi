import Foundation
import SwiftData
import Testing
@testable import NomadFi

@MainActor
struct SpendingViewModelTests {

    @Test func aTouchOnTheWheelPicksTheSliceUnderIt() {
        let category = SpendingCategorySlice(category: .food, total: 100, subcategories: [
            .init(id: "food.groceries", subcategory: SpendingTaxonomy.bundled.subcategory(id: "food.groceries"), total: 60, merchants: []),
            .init(id: "food.other", subcategory: nil, total: 40, merchants: []),
        ])
        let slices = SpendingViewModel.subcategorySlices(of: category)

        #expect(slices.map(\.share) == [0.6, 0.4])
        #expect(slices.map(\.colorRank) == [0, nil])
        #expect(SpendingViewModel.sliceID(atAngleValue: 10, in: slices) == "food.groceries")
        #expect(SpendingViewModel.sliceID(atAngleValue: 60, in: slices) == "food.groceries")
        #expect(SpendingViewModel.sliceID(atAngleValue: 61, in: slices) == "food.other")
    }

    @Test func unrecognizedMerchantsAreSuggestedOnceAndSorted() async throws {
        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        for (name, amount) in [("Mystery Wheels", -25.0), ("Odd Shop", -5.0), ("Lyft", -10.0)] {
            context.insert(Transaction(merchantName: name, originalAmount: amount, originalCurrency: .cad, category: .transport))
        }
        try context.save()
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = SpendingViewModel(
            homeCurrency: .cad,
            suggester: StubSuggester(answers: ["Mystery Wheels": "transport.carShare"]),
            suggestionStore: SpendingSuggestionStore(fileURL: fileURL)
        )
        viewModel.period = .month
        await viewModel.load(in: container)
        #expect(viewModel.breakdown?.slice(for: .transport)?.subcategories.last?.merchants.count == 2)

        await viewModel.sortUnrecognizedMerchants(in: container)
        let transport = try #require(viewModel.breakdown?.slice(for: .transport))
        #expect(transport.subcategories.map(\.id) == ["transport.carShare", "transport.rideShare", "transport.other"])
        #expect(transport.subcategories.last?.merchants.map(\.name) == ["Odd Shop"])
        #expect(SpendingSuggestionStore(fileURL: fileURL).load() == ["MYSTERY WHEELS": "transport.carShare", "ODD SHOP": ""])
    }
}

private struct StubSuggester: SpendingMerchantSuggesting {
    let answers: [String: String]
    var isAvailable: Bool { true }

    func suggest(merchantName: String, category: TransactionCategory, options: [SpendingSubcategory]) async throws -> String? {
        answers[merchantName]
    }
}
