// PurchaseTravelContextTests.swift
// NomadFi
//
// Pure-logic coverage for the Phase 3 follow-through travel-signal
// derivation. The type is value-only and the derivation function
// is pure over its inputs, so these tests stay off SwiftData.

import Foundation
import Testing

@testable import NomadFi

struct PurchaseTravelContextTests {

    // MARK: - Helpers

    private func context(
        currency: CurrencyCode = .usd,
        category: MerchantCategory = .general,
        location: String = ""
    ) -> PurchaseContext {
        PurchaseContext(
            merchantName: "Test merchant",
            category: category,
            amount: 100,
            currencyCode: currency,
            countryCode: location,
            timingText: ""
        )
    }

    // MARK: - Empty / no signal

    @Test("Empty account list and no hints ⇒ all flags false; isLikelyCrossBorder false")
    func emptyInputsHaveNoTravelSignal() {
        let travel = PurchaseTravelContext.from(
            context: context(),
            accountCurrencies: []
        )
        #expect(travel.isCrossCurrency == false)
        #expect(travel.hasLocationHint == false)
        #expect(travel.isTravelCategory == false)
        #expect(travel.isLikelyCrossBorder == false)
    }

    @Test("Same-currency accounts and no hints ⇒ no travel signal")
    func sameCurrencyOnlyHasNoTravelSignal() {
        let travel = PurchaseTravelContext.from(
            context: context(currency: .usd),
            accountCurrencies: ["USD", "USD"]
        )
        #expect(travel.isCrossCurrency == false)
        #expect(travel.isLikelyCrossBorder == false)
    }

    // MARK: - Cross-currency

    @Test("Any account in a different currency from the purchase flips isCrossCurrency true")
    func mismatchedAccountCurrencyFlipsCrossCurrency() {
        let travel = PurchaseTravelContext.from(
            context: context(currency: .usd),
            accountCurrencies: ["USD", "CAD"]
        )
        #expect(travel.isCrossCurrency == true)
        #expect(travel.isLikelyCrossBorder == true)
    }

    @Test("Currency match comparison is case-insensitive")
    func currencyMatchIsCaseInsensitive() {
        let travel = PurchaseTravelContext.from(
            context: context(currency: .usd),
            accountCurrencies: ["usd"]
        )
        #expect(travel.isCrossCurrency == false)
        #expect(travel.isLikelyCrossBorder == false)
    }

    // MARK: - Location hint

    @Test("Non-empty location hint flips hasLocationHint and isLikelyCrossBorder")
    func nonEmptyLocationHintFlipsTravelSignal() {
        let travel = PurchaseTravelContext.from(
            context: context(location: "Toronto"),
            accountCurrencies: ["USD"]
        )
        #expect(travel.hasLocationHint == true)
        #expect(travel.isLikelyCrossBorder == true)
    }

    @Test("Whitespace-only location hint does not count")
    func whitespaceLocationHintDoesNotCount() {
        let travel = PurchaseTravelContext.from(
            context: context(location: "   "),
            accountCurrencies: ["USD"]
        )
        #expect(travel.hasLocationHint == false)
        #expect(travel.isLikelyCrossBorder == false)
    }

    // MARK: - Travel category

    @Test(".travel merchant category alone flips isTravelCategory and isLikelyCrossBorder")
    func travelCategoryFlipsTravelSignal() {
        let travel = PurchaseTravelContext.from(
            context: context(category: .travel),
            accountCurrencies: ["USD"]
        )
        #expect(travel.isTravelCategory == true)
        #expect(travel.isLikelyCrossBorder == true)
    }

    @Test("Non-travel category alone produces no travel signal")
    func nonTravelCategoryStaysQuiet() {
        let travel = PurchaseTravelContext.from(
            context: context(category: .groceries),
            accountCurrencies: ["USD"]
        )
        #expect(travel.isTravelCategory == false)
        #expect(travel.isLikelyCrossBorder == false)
    }

    // MARK: - Combined

    @Test("Any single signal is enough to flip isLikelyCrossBorder true")
    func anySignalFlipsCrossBorder() {
        let signals: [PurchaseTravelContext] = [
            .from(context: context(currency: .usd), accountCurrencies: ["CAD"]),
            .from(context: context(location: "Tokyo"), accountCurrencies: ["USD"]),
            .from(context: context(category: .travel), accountCurrencies: ["USD"]),
        ]
        for signal in signals {
            #expect(signal.isLikelyCrossBorder == true)
        }
    }
}
