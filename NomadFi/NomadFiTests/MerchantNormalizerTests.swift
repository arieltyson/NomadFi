// MerchantNormalizerTests.swift
// NomadFi
//
// Pure rule coverage for `MerchantNormalizer`. The normalizer is
// deliberately conservative — tests pin both what it *does*
// normalize and what it intentionally leaves alone.

import Foundation
import Testing

@testable import NomadFi

struct MerchantNormalizerTests {

    // MARK: - Basic cleanup

    @Test("Whitespace and casing are canonicalised")
    func trimsAndUppercases() {
        #expect(MerchantNormalizer.normalize("  coffee shop  ") == "COFFEE SHOP")
    }

    @Test("Empty and whitespace-only input returns an empty string")
    func emptyInputStaysEmpty() {
        #expect(MerchantNormalizer.normalize("") == "")
        #expect(MerchantNormalizer.normalize("   ") == "")
    }

    // MARK: - Processor prefixes

    @Test("Square prefix is stripped from the merchant name")
    func squarePrefixStripped() {
        #expect(MerchantNormalizer.normalize("SQ *COFFEE SHOP") == "COFFEE SHOP")
    }

    @Test("PayPal prefix is stripped from the merchant name")
    func paypalPrefixStripped() {
        #expect(MerchantNormalizer.normalize("PAYPAL *NETFLIX") == "NETFLIX")
    }

    @Test("Toast prefix is stripped from the merchant name")
    func toastPrefixStripped() {
        #expect(MerchantNormalizer.normalize("TST*GROCERY STORE") == "GROCERY STORE")
    }

    @Test("Amazon marketplace prefix is stripped")
    func amazonMarketplacePrefixStripped() {
        #expect(MerchantNormalizer.normalize("AMZN MKTP US*ORDER") == "ORDER")
    }

    // MARK: - Trailing noise

    @Test("Trailing store number suffix is stripped")
    func trailingStoreNumberStripped() {
        #expect(MerchantNormalizer.normalize("GROCERY STORE 12345") == "GROCERY STORE")
    }

    @Test("Trailing hash-number store marker is stripped")
    func trailingHashNumberStripped() {
        #expect(MerchantNormalizer.normalize("BOOKSTORE #421") == "BOOKSTORE")
    }

    @Test("Trailing short date is stripped")
    func trailingShortDateStripped() {
        #expect(MerchantNormalizer.normalize("COFFEE 04/23") == "COFFEE")
    }

    @Test("Trailing CITY ST ZIP block is stripped when shape matches")
    func trailingCityStateZipStripped() {
        #expect(MerchantNormalizer.normalize("COFFEE SHOP NEW YORK NY 10001") == "COFFEE SHOP")
    }

    @Test("Unknown trailing text is preserved — no over-normalisation")
    func unknownSuffixPreserved() {
        #expect(MerchantNormalizer.normalize("LOCAL CAFÉ MAIN BRANCH") == "LOCAL CAFÉ MAIN BRANCH")
    }

    // MARK: - Punctuation / whitespace collapse

    @Test("Repeated asterisks collapse to one")
    func repeatedAsterisksCollapse() {
        #expect(MerchantNormalizer.normalize("COFFEE***SHOP") == "COFFEE*SHOP")
    }

    @Test("Internal double-spaces collapse to a single space")
    func repeatedWhitespaceCollapses() {
        #expect(MerchantNormalizer.normalize("COFFEE    SHOP") == "COFFEE SHOP")
    }

    @Test("Stacked processor prefixes are stripped in a single pass")
    func stackedPrefixesStripped() {
        #expect(MerchantNormalizer.normalize("PP*SQ *COFFEE") == "COFFEE")
    }
}
