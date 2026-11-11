import Testing
@testable import NomadFi

struct CurrencySymbolTests {

    @Test func everyCurrencyIsWrittenAsCodeThenSign() {
        #expect(CurrencyCode.usd.symbol == "USD$")
        #expect(CurrencyCode.cad.symbol == "CAD$")
        #expect(CurrencyCode.ttd.symbol == "TTD$")
        #expect(CurrencyCode.gbp.symbol == "GBP£")
        #expect(CurrencyCode.eur.symbol == "EUR€")
        #expect(CurrencyCode.inr.symbol == "INR₹")
        #expect(CurrencyCode.ngn.symbol == "NGN₦")
        #expect(CurrencyCode.cny.symbol == "CNY¥")
    }

    @Test func noTwoCurrenciesShareASymbol() {
        let symbols = CurrencyCode.allCases.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
        #expect(CurrencyCode.allCases.allSatisfy { $0.symbol.hasPrefix($0.rawValue) && $0.symbol.count > $0.rawValue.count })
    }
}
