import Foundation
import Testing
@testable import NomadFi

struct SpendingClassifierTests {

    private let classifier = SpendingClassifier(taxonomy: .bundled)

    private func classify(
        _ name: String,
        _ category: TransactionCategory,
        code: String? = nil,
        using classifier: SpendingClassifier? = nil
    ) -> String? {
        (classifier ?? self.classifier).subcategory(
            merchantKey: MerchantNormalizer.normalize(name),
            merchantName: name,
            category: category,
            providerCode: code
        )?.id
    }

    @Test func theBundledTaxonomyLoadsWithUniqueIDs() {
        let ids = SpendingTaxonomy.bundled.subcategories.map(\.id)
        #expect(!ids.isEmpty)
        #expect(Set(ids).count == ids.count)
    }

    @Test(arguments: [
        ("EVO Car Share", TransactionCategory.transport, "transport.carShare"),
        ("CHEVRON 01234", .transport, "transport.fuel"),
        ("UBER *TRIP", .transport, "transport.rideShare"),
        ("Lyft", .transport, "transport.rideShare"),
        ("AIR CANADA 0142", .transport, "transport.flights"),
        ("UBER *EATS", .food, "food.delivery"),
        ("Nesters Market", .food, "food.groceries"),
        ("SAFEWAY #4920", .food, "food.groceries"),
        ("Kitchen Sushi Bar", .food, "food.restaurants"),
    ])
    func brandsAndWordsSortPurchases(name: String, category: TransactionCategory, expected: String) {
        #expect(classify(name, category) == expected)
    }

    @Test func aBrandOutranksTheBankFeedAndTheFeedOutranksAWord() {
        #expect(classify("DOORDASH*THAI HOUSE", .food, code: "FOOD_AND_DRINK_RESTAURANT") == "food.delivery")
        #expect(classify("The Wine Bar", .food, code: "FOOD_AND_DRINK_RESTAURANT") == "food.restaurants")
        #expect(classify("Corner Spot", .food, code: "FOOD_AND_DRINK_RESTAURANT") == "food.restaurants")
    }

    @Test func aPersonsRuleWinsButOnlyWithinTheCategory() {
        let ruled = SpendingClassifier(
            taxonomy: .bundled,
            merchantRules: [MerchantNormalizer.normalize("Mystery Co"): "transport.carShare"]
        )
        #expect(classify("Mystery Co", .transport, using: ruled) == "transport.carShare")
        #expect(classify("Mystery Co", .food, using: ruled) == nil)
        #expect(classify("Mystery Co", .transport) == nil)
    }
}
