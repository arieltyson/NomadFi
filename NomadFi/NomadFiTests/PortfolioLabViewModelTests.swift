// PortfolioLabViewModelTests.swift
// NomadFi
//
// Pins Tools → Portfolio Lab: bundled data, home-currency support,
// live prices behind the person's own token, and Tiingo parsing.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PortfolioLabViewModelTests {

    private final class TokenBox: @unchecked Sendable {
        var value: String?
        init(_ value: String? = nil) { self.value = value }
    }

    private func store(_ box: TokenBox) -> PortfolioLabViewModel.TokenStore {
        .init(load: { box.value }, save: { box.value = $0; return true }, delete: { box.value = nil })
    }

    private func viewModel(token: String? = nil, failure: PortfolioLabPriceServiceError? = nil,
                           home: CurrencyCode = .cad) -> PortfolioLabViewModel {
        let model = PortfolioLabViewModel(priceService: MockPortfolioLabPriceService(failure: failure),
                                          tokenStore: store(TokenBox(token)))
        model.setJurisdictions([JurisdictionProfile(countryCode: "CA", countryName: "Canada",
                                                    currencyCode: home, isHome: true)])
        return model
    }

    @Test("The app bundle carries the Bank of Canada snapshot and illustrative prices")
    func bundledResourcesLoad() throws {
        let snapshot = try PortfolioLabResources.fxSnapshot()
        #expect(snapshot.fx.base == "USD" && snapshot.fx.quote == "CAD")
        #expect(snapshot.fx.points.count >= PortfolioLabReturns.minimumMonths + 1)
        #expect(snapshot.source.terms.absoluteString == "https://www.bankofcanada.ca/terms/")
        #expect(try PortfolioLabResources.sampleMarket().note.contains("Illustrative"))
    }

    @Test("Sample mode optimizes every conversion method for a Canadian home")
    func sampleModeRuns() async throws {
        let model = viewModel()
        await model.run()
        let result = try #require(model.result)
        #expect(result.comparisons.map(\.conversion.id) == ["bank", "brokerage", "norbertsGambit"])
        #expect(result.assets.last?.kind == .cash)
        #expect(abs(result.selected.weights.reduce(0, +) - 1) < 1e-9)
        #expect(model.errorMessage == nil)
    }

    @Test("With no CAD or USD jurisdiction, Portfolio Lab explains instead of computing")
    func unsupportedHomeCurrency() async {
        let model = viewModel(home: .ttd)
        await model.run()
        #expect(model.lacksSupportedCurrency)
        #expect(model.result == nil)
    }

    @Test("A Trinidad and Tobago home with a Canadian jurisdiction invests from CAD")
    func fallsBackToAnotherJurisdiction() async throws {
        let model = PortfolioLabViewModel(priceService: MockPortfolioLabPriceService(), tokenStore: store(TokenBox()))
        model.setJurisdictions([
            JurisdictionProfile(countryCode: "TT", currencyCode: .ttd, isHome: true),
            JurisdictionProfile(countryCode: "US", currencyCode: .usd, displayOrder: 2),
            JurisdictionProfile(countryCode: "CA", currencyCode: .cad, displayOrder: 1),
        ])
        #expect(model.investableCurrencies == [.usd, .cad])
        #expect(model.homeCurrency == .usd && !model.lacksSupportedCurrency)
        model.homeCurrency = .cad
        await model.run()
        #expect(try #require(model.result).selected.foreignShare >= 0)
    }

    @Test("Live mode asks for a token before fetching anything")
    func liveModeNeedsToken() async {
        let model = viewModel()
        model.source = .live
        await model.run()
        #expect(model.result == nil)
        #expect(model.errorMessage == PortfolioLabPriceServiceError.missingToken.localizedDescription)
    }

    @Test("Live mode with a token uses only the US-listed funds plus cash")
    func liveModeUsesLiveCatalog() async throws {
        let model = viewModel(token: String(repeating: "a1", count: 20))
        model.source = .live
        await model.run()
        let symbols = try #require(model.result).assets.map(\.symbol)
        #expect(symbols == PortfolioLabLiveCatalog.funds.map(\.symbol) + [PortfolioLabRequest.cashSymbol])
    }

    @Test("Tiingo failures surface as a readable message")
    func liveFailureIsReadable() async {
        let model = viewModel(token: String(repeating: "b2", count: 20), failure: .unauthorized)
        model.source = .live
        await model.run()
        #expect(model.errorMessage == PortfolioLabPriceServiceError.unauthorized.localizedDescription)
    }

    @Test("Only hexadecimal tokens of a plausible length are stored; removing one returns to sample")
    func tokenLifecycle() {
        let box = TokenBox()
        let model = PortfolioLabViewModel(priceService: MockPortfolioLabPriceService(), tokenStore: store(box))
        #expect(!model.saveToken("not a token"))
        #expect(model.saveToken("  " + String(repeating: "0f", count: 20) + "\n"))
        #expect(box.value == String(repeating: "0f", count: 20))
        model.source = .live
        model.removeToken()
        #expect(box.value == nil && !model.hasToken && model.source == .sample)
    }

    @Test("Tiingo month-end bars become adjusted closes keyed by month")
    func parsesTiingoBars() throws {
        let json = """
        [{"date":"2024-01-31T00:00:00.000Z","close":220.1,"adjClose":215.5},
         {"date":"2024-02-29T00:00:00.000Z","close":231.0,"adjClose":null},
         {"date":"bad","close":1.0}]
        """
        let closes = try TiingoPriceService.parse(Data(json.utf8), symbol: "VTI")
        #expect(closes == [.init(month: "2024-01", close: 215.5), .init(month: "2024-02", close: 231.0)])
        #expect(throws: PortfolioLabPriceServiceError.invalidResponse("VTI")) {
            try TiingoPriceService.parse(Data("{}".utf8), symbol: "VTI")
        }
    }
}
