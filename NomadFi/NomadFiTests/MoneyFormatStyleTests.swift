// MoneyFormatStyleTests.swift
// NomadFi
//
// Pins NomadFi's money format: a symbol, the amount, a space, and the
// ISO code — the same shape for every currency, whatever the region.

import Foundation
import Testing

@testable import NomadFi

struct MoneyFormatStyleTests {

    private let canada = Locale(identifier: "en_CA")

    @Test(
        "Every currency gets a symbol and its code, whatever the device region",
        arguments: [
            ("en_CA", "CAD", "$3,250.75 CAD"),
            ("en_CA", "USD", "$3,250.75 USD"),
            ("en_CA", "TTD", "$3,250.75 TTD"),
            ("en_US", "CAD", "$3,250.75 CAD"),
            ("en_US", "USD", "$3,250.75 USD"),
            ("en_TT", "TTD", "$3,250.75 TTD"),
        ]
    )
    func symbolThenCode(locale: String, code: String, expected: String) {
        let formatted = 3_250.75.formatted(.money(code: code).locale(Locale(identifier: locale)))
        #expect(formatted == expected)
    }

    @Test("Negative amounts keep the sign before the symbol")
    func negativeAmounts() {
        #expect((-125.0).formatted(.money(code: "USD").locale(canada)) == "-$125.00 USD")
    }

    @Test("Precision applies to the amount, not the code")
    func precision() {
        let style = MoneyFormatStyle.money(code: "CAD").locale(canada).precision(.fractionLength(0))
        #expect(1_234.56.formatted(style) == "$1,235 CAD")
    }

    @Test("A table whose header names the currency can hide the code")
    func codeHidden() {
        let style = MoneyFormatStyle.money(code: "CAD").locale(canada).precision(.fractionLength(0)).codeHidden()
        #expect(156.0.formatted(style) == "$156")
    }

    @Test("A code is never written twice")
    func codeAppearsOnce() {
        let formatted = 10.0.formatted(.money(code: "CHF").locale(canada))
        #expect(formatted.ranges(of: "CHF").count == 1)
    }

    @Test("VoiceOver hears the currency's name, not its code")
    func spokenAmount() {
        let spoken = MoneyFormatStyle.spokenAmount(3_250.75, code: "CAD")
        #expect(spoken.localizedStandardContains("Canadian"))
        #expect(!spoken.contains("CAD"))
    }
}
