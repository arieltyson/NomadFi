import Foundation

/// How much risk the person is willing to trade for expected return.
public enum PortfolioLabRiskProfile: String, Codable, CaseIterable, Sendable {
    case cautious, balanced, growth
    public var riskAversion: Double {
        switch self {
        case .cautious: 8
        case .balanced: 3
        case .growth: 1.2
        }
    }
}

public struct PortfolioLabRequest: Sendable {
    public var series: [PortfolioLabPriceSeries]
    public var fx: PortfolioLabFXSeries?
    public var homeCurrency: String
    public var amount: Double
    public var conversion: PortfolioLabConversionMethod
    public var comparedConversions: [PortfolioLabConversionMethod]
    public var profile: PortfolioLabRiskProfile
    public var expectation: PortfolioLabExpectation
    /// Annual rate on uninvested home-currency cash, or `nil` to leave cash out.
    public var cashRate: Double?
    public var maxWeight: Double
    public var commissionPercent: Double
    public var rebalanceEvery: Int

    public static let cashSymbol = "CASH"

    public init(series: [PortfolioLabPriceSeries], fx: PortfolioLabFXSeries?, homeCurrency: String, amount: Double,
                conversion: PortfolioLabConversionMethod = .bank,
                comparedConversions: [PortfolioLabConversionMethod] = PortfolioLabConversionMethod.standard,
                profile: PortfolioLabRiskProfile = .balanced, expectation: PortfolioLabExpectation = .shrunkHistorical,
                cashRate: Double? = 0.02, maxWeight: Double = 0.6, commissionPercent: Double = 0, rebalanceEvery: Int = 12) {
        self.series = series; self.fx = fx; self.homeCurrency = homeCurrency; self.amount = amount
        self.conversion = conversion; self.comparedConversions = comparedConversions; self.profile = profile
        self.expectation = expectation; self.cashRate = cashRate; self.maxWeight = maxWeight
        self.commissionPercent = commissionPercent; self.rebalanceEvery = rebalanceEvery
    }
}

/// One conversion method's optimal mix and how it would have done.
public struct PortfolioLabScenario: Equatable, Sendable {
    public var conversion: PortfolioLabConversionMethod
    public var weights: [Double]
    /// Share of the money converted out of the home currency.
    public var foreignShare: Double
    public var expectedReturn: Double
    public var expectedVolatility: Double
    public var backtest: PortfolioLabBacktest
}

public struct PortfolioLabResult: Equatable, Sendable {
    public var assets: [PortfolioLabAsset]
    public var months: [String]
    public var issues: [PortfolioLabDataIssue]
    public var selected: PortfolioLabScenario
    public var comparisons: [PortfolioLabScenario]
}

/// Data checks → home-currency returns → risk model → costs → optimizer → backtest,
/// once for the chosen conversion method and once for each method it is compared with.
public enum PortfolioLabEngine {
    public static func run(_ request: PortfolioLabRequest) throws -> PortfolioLabResult {
        let issues = request.series.flatMap { PortfolioLabDataQuality.issues(in: $0) }
        var panel = try PortfolioLabReturns.homeCurrencyPanel(series: request.series, fx: request.fx,
                                                              homeCurrency: request.homeCurrency)
        var model = PortfolioLabRiskModel.estimate(from: panel, expectation: request.expectation)
        var assets = request.series.map(\.asset)
        if let rate = request.cashRate {
            let cash = PortfolioLabAsset(symbol: PortfolioLabRequest.cashSymbol, name: "Cash",
                                         currency: request.homeCurrency, kind: .cash)
            assets.append(cash)
            model = model.addingCash(symbol: cash.symbol, annualRate: rate)
            let monthly = pow(1 + rate, 1.0 / 12) - 1
            panel = .init(months: panel.months, symbols: panel.symbols + [cash.symbol],
                          returns: panel.returns.map { $0 + [monthly] })
        }

        func scenario(_ conversion: PortfolioLabConversionMethod) throws -> PortfolioLabScenario {
            let costs = PortfolioLabCosts.perUnit(assets: assets, homeCurrency: request.homeCurrency, conversion: conversion,
                                                  amount: request.amount, commissionPercent: request.commissionPercent)
            let solution = try PortfolioLabOptimizer.optimize(expectedReturns: model.expectedReturns,
                                                              covariance: model.covariance, costs: costs,
                                                              riskAversion: request.profile.riskAversion,
                                                              maxWeight: request.maxWeight)
            let foreign = zip(assets, solution.weights).reduce(0) { $0 + ($1.0.currency == request.homeCurrency ? 0 : $1.1) }
            return .init(conversion: conversion, weights: solution.weights, foreignShare: foreign,
                         expectedReturn: model.expectedReturn(of: solution.weights),
                         expectedVolatility: model.volatility(of: solution.weights),
                         backtest: PortfolioLabBacktester.run(panel: panel, weights: solution.weights, amount: request.amount,
                                                              costs: costs, rebalanceEvery: request.rebalanceEvery))
        }

        return .init(assets: assets, months: panel.months, issues: issues, selected: try scenario(request.conversion),
                     comparisons: try request.comparedConversions.map(scenario))
    }
}
