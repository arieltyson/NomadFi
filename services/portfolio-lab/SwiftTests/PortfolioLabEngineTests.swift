import Foundation
import Testing
@testable import PortfolioLabEngine

struct PortfolioLabEngineTests {
    private func asset(_ symbol: String, _ currency: String = "USD", _ kind: PortfolioLabAssetKind = .equity) -> PortfolioLabAsset {
        .init(symbol: symbol, name: symbol, currency: currency, kind: kind)
    }
    private func closes(_ values: [Double], from start: String = "2020-01") -> [PortfolioLabClose] {
        let first = PortfolioLabCalendar.index(of: start)!
        return values.enumerated().map { .init(month: PortfolioLabCalendar.month(at: first + $0.offset), close: $0.element) }
    }
    private func trending(_ count: Int, growth: Double, wobble: Double, phase: Double = 0) -> [Double] {
        (0..<count).map { 100 * pow(1 + growth, Double($0)) * (1 + wobble * sin(Double($0) * 1.3 + phase)) }
    }

    @Test func calendarRoundTripsAndRejectsMalformedMonths() {
        #expect(PortfolioLabCalendar.index(of: "2024-12").map(PortfolioLabCalendar.month(at:)) == "2024-12")
        #expect(PortfolioLabCalendar.index(of: "2025-01")! - PortfolioLabCalendar.index(of: "2024-12")! == 1)
        for bad in ["2024-13", "2024-1", "24-01", "2024/01", "2024-00"] { #expect(PortfolioLabCalendar.index(of: bad) == nil) }
    }

    @Test func flagsEveryVendorProblemOnceAndInMonthOrder() {
        let series = PortfolioLabPriceSeries(asset: asset("AAA"), closes: [
            .init(month: "2024-01", close: 10), .init(month: "2024-01", close: 11), .init(month: "2024-02", close: 10),
            .init(month: "2024-03", close: 10), .init(month: "2024-04", close: 10), .init(month: "2024-06", close: 20),
            .init(month: "2024-07", close: -1), .init(month: "2024-08", close: 20.5), .init(month: "June", close: 1),
        ])
        let found = PortfolioLabDataQuality.issues(in: series).map { "\($0.month) \($0.kind.rawValue)" }
        #expect(found == ["2024-01 duplicate", "2024-04 stale", "2024-05 missing", "2024-06 jump", "2024-07 nonpositive",
                          "June unreadableMonth"])
    }

    @Test func convertsForeignFundsIntoTheHomeCurrencyBothWays() throws {
        let usd = PortfolioLabPriceSeries(asset: asset("VTI"), closes: closes(Array(repeating: 100, count: 30)))
        let cad = PortfolioLabPriceSeries(asset: asset("XIC", "CAD"), closes: closes(Array(repeating: 50, count: 30)))
        let fx = PortfolioLabFXSeries(base: "USD", quote: "CAD", points: closes((0..<30).map { 1.30 + 0.01 * Double($0) }))
        let inCAD = try PortfolioLabReturns.homeCurrencyPanel(series: [usd, cad], fx: fx, homeCurrency: "CAD")
        #expect(abs(inCAD.returns[0][0] - (1.31 / 1.30 - 1)) < 1e-15)
        #expect(inCAD.returns[0][1] == 0)
        let inUSD = try PortfolioLabReturns.homeCurrencyPanel(series: [usd, cad], fx: fx, homeCurrency: "USD")
        #expect(abs(inUSD.returns[0][1] - (1.30 / 1.31 - 1)) < 1e-15)
        #expect(inUSD.months.count == 29 && inUSD.months.first == "2020-02")
    }

    @Test func refusesShortHistoryAndCurrenciesWithoutARate() {
        let short = PortfolioLabPriceSeries(asset: asset("VTI", "USD"), closes: closes(trending(10, growth: 0.01, wobble: 0.02)))
        #expect(throws: PortfolioLabError.insufficientHistory(months: 9)) {
            try PortfolioLabReturns.homeCurrencyPanel(series: [short], fx: nil, homeCurrency: "USD")
        }
        #expect(throws: PortfolioLabError.unsupportedCurrency("USD")) {
            try PortfolioLabReturns.homeCurrencyPanel(series: [short], fx: nil, homeCurrency: "TTD")
        }
    }

    @Test func gapsBreakReturnsInsteadOfSpanningThem() throws {
        var values = closes(trending(40, growth: 0.01, wobble: 0.03))
        values.remove(at: 20)
        let panel = try PortfolioLabReturns.homeCurrencyPanel(series: [.init(asset: asset("VTI"), closes: values)],
                                                              fx: nil, homeCurrency: "USD")
        #expect(panel.months.count == 37)
        #expect(!panel.months.contains(PortfolioLabCalendar.month(at: PortfolioLabCalendar.index(of: "2020-01")! + 21)))
    }

    @Test func optimizerMatchesClosedFormAndRespectsCostsAndCaps() throws {
        let diagonal = [[0.04, 0], [0, 0.04]]
        let free = try PortfolioLabOptimizer.optimize(expectedReturns: [0.02, 0.01], covariance: diagonal,
                                                      riskAversion: 1, maxWeight: 1)
        #expect(abs(free.weights[0] - 0.5625) < 1e-9 && free.converged)
        let costly = try PortfolioLabOptimizer.optimize(expectedReturns: [0.02, 0.01], covariance: diagonal, previous: [0.5, 0.5],
                                                        costs: [0.1, 0.1], riskAversion: 1, maxWeight: 1)
        #expect(abs(costly.weights[0] - 0.5) < 1e-9)
        let capped = try PortfolioLabOptimizer.optimize(expectedReturns: [0.05, 0, 0, 0], covariance: (0..<4).map { i in (0..<4).map { i == $0 ? 0.01 : 0 } },
                                                        riskAversion: 1, maxWeight: 0.4)
        for (actual, expected) in zip(capped.weights, [0.4, 0.2, 0.2, 0.2]) { #expect(abs(actual - expected) < 1e-9) }
        #expect(throws: PortfolioLabError.infeasibleCap(maxWeight: 0.3, assets: 3)) {
            try PortfolioLabOptimizer.optimize(expectedReturns: [0, 0, 0], covariance: diagonal, riskAversion: 1, maxWeight: 0.3)
        }
    }

    @Test func noRandomFeasiblePortfolioBeatsTheOptimizer() throws {
        let mu = [0.07, 0.05, 0.03, 0.02]
        let sigma = [[0.030, 0.012, 0.002, 0], [0.012, 0.025, 0.003, 0], [0.002, 0.003, 0.004, 0], [0, 0, 0, 0]]
        let costs = [0.025, 0.025, 0.0, 0.0], lambda = 3.0, cap = 0.6
        let best = try PortfolioLabOptimizer.optimize(expectedReturns: mu, covariance: sigma, costs: costs,
                                                      riskAversion: lambda, maxWeight: cap)
        var generator = SplitMix(seed: 42)
        for _ in 0..<5_000 {
            var w = (0..<4).map { _ in generator.next() }
            let total = w.reduce(0, +); w = w.map { $0 / total }
            guard w.allSatisfy({ $0 <= cap }) else { continue }
            let score = PortfolioLabOptimizer.objective(w, mu: mu, sigma: sigma, previous: [0, 0, 0, 0], costs: costs, lambda: lambda)
            #expect(score <= best.objective + 1e-12)
        }
    }

    @Test func backtestDriftsPaysCostsAndRebalances() {
        let panel = PortfolioLabReturnPanel(months: ["2024-01", "2024-02"], symbols: ["A", "B"], returns: [[0.10, -0.10], [0, 0.02]])
        let result = PortfolioLabBacktester.run(panel: panel, weights: [0.5, 0.5], amount: 1000, costs: [0.001, 0.001], rebalanceEvery: 1)
        // Buy 1,000 at 10 bps (1.00), drift to 549.45 / 449.55, rebalance 0.1 of 999 at 10 bps.
        #expect(abs(result.initialCost - 1) < 1e-12)
        let afterJanuary = 999.0
        let rebalanceCost = 0.001 * (abs(0.5 * afterJanuary - 549.45) + abs(0.5 * afterJanuary - 449.55))
        #expect(abs(result.points[1].value - (afterJanuary - rebalanceCost)) < 1e-9)
        #expect(abs(result.endingValue - (afterJanuary - rebalanceCost) * 1.01) < 1e-9)
        #expect(result.points.first?.month == "2023-12")
    }

    @Test func expensiveConversionKeepsMoreMoneyAtHome() throws {
        let months = 96
        let series = [
            PortfolioLabPriceSeries(asset: asset("VTI"), closes: closes(trending(months, growth: 0.008, wobble: 0.05))),
            PortfolioLabPriceSeries(asset: asset("VXUS"), closes: closes(trending(months, growth: 0.006, wobble: 0.05, phase: 1))),
            PortfolioLabPriceSeries(asset: asset("BND"), closes: closes(trending(months, growth: 0.003, wobble: 0.01, phase: 2))),
        ]
        let fx = PortfolioLabFXSeries(base: "USD", quote: "CAD", points: closes(trending(months, growth: 0, wobble: 0.02, phase: 3)))
        let result = try PortfolioLabEngine.run(.init(series: series, fx: fx, homeCurrency: "CAD", amount: 5_000))
        let byMethod = Dictionary(uniqueKeysWithValues: result.comparisons.map { ($0.conversion.id, $0) })
        #expect(byMethod["bank"]!.foreignShare <= byMethod["brokerage"]!.foreignShare + 1e-9)
        #expect(byMethod["brokerage"]!.foreignShare <= byMethod["norbertsGambit"]!.foreignShare + 1e-9)
        #expect(byMethod["bank"]!.backtest.initialCost > byMethod["norbertsGambit"]!.backtest.initialCost)
        #expect(result.assets.last?.kind == .cash)
        for scenario in result.comparisons { #expect(abs(scenario.weights.reduce(0, +) - 1) < 1e-9) }
    }
}

/// Deterministic uniform numbers in [0, 1) so the property test is reproducible.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}
