import MapKit
import Testing
@testable import NomadFi

@MainActor
struct PurchaseCaptureTests {

    // MARK: - Spoken purchases

    @Test func aFullSentenceYieldsAmountMerchantAndCategory() {
        let utterance = PurchaseUtteranceParser.parse("$40 at Whole Foods")
        #expect(utterance.amount == 40)
        #expect(utterance.merchantName == "Whole Foods")
        #expect(utterance.category == .groceries)
        #expect(utterance.currency == nil, "A bare dollar sign names no country, so the currency is left alone")
    }

    @Test func aNamedCurrencyAndTrailingPurposeAreUnderstood() {
        let utterance = PurchaseUtteranceParser.parse("1,250.50 US dollars from Air Canada for a flight")
        #expect(utterance.amount == 1250.5)
        #expect(utterance.currency == .usd)
        #expect(utterance.merchantName == "Air Canada")
        #expect(utterance.category == .travel)
    }

    @Test func foodDeliveryIsDiningNotTransit() {
        #expect(PurchaseUtteranceParser.parse("25 at Uber Eats").category == .dining)
        #expect(PurchaseUtteranceParser.parse("25 for an Uber").category == .transit)
    }

    @Test func nothingUnderstoodIsEmptyRatherThanGuessed() {
        #expect(PurchaseUtteranceParser.parse("   ").isEmpty)
        #expect(PurchaseUtteranceParser.parse("hello there").isEmpty)
    }

    // MARK: - Places

    @Test func mapsCategoriesBecomeRewardCategories() {
        #expect(PlaceCategoryMapper.merchantCategory(for: .foodMarket) == .groceries)
        #expect(PlaceCategoryMapper.merchantCategory(for: .cafe) == .dining)
        #expect(PlaceCategoryMapper.merchantCategory(for: .airport) == .travel)
        #expect(PlaceCategoryMapper.merchantCategory(for: .pharmacy) == .health)
        #expect(PlaceCategoryMapper.merchantCategory(for: .museum) == .general)
        #expect(PlaceCategoryMapper.merchantCategory(for: nil) == .general)
    }

    // MARK: - Filling in the purchase

    @Test func applyingAPlaceOrUtteranceOnlyChangesWhatItKnows() {
        let record = PurchaseDecisionRecord()
        let model = PurchaseDecisionBriefViewModel(record: record)
        model.apply(NearbyPlace(id: "1", name: "Corner Cafe", category: .dining))
        #expect(record.merchantName == "Corner Cafe")
        #expect(record.categoryRawValue == MerchantCategory.dining.rawValue)

        let currencyBefore = record.currencyCodeRawValue
        model.apply(PurchaseUtterance(merchantName: nil, amount: 12.5, currency: nil, category: nil))
        #expect(record.amount == 12.5)
        #expect(record.merchantName == "Corner Cafe", "An unspoken merchant is not cleared")
        #expect(record.currencyCodeRawValue == currencyBefore)
    }
}
