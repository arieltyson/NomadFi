import Foundation
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
}
