import Foundation

/// How expected returns are formed. Neither is a forecast; both are teaching assumptions.
public enum PortfolioLabExpectation: String, Codable, CaseIterable, Sendable {
    /// Each fund's own history, pulled halfway toward the average of all funds.
    case shrunkHistorical
    /// Every fund expects the same return, so the optimizer only trades off risk and cost.
    case equal
}

/// Annualized expected returns and covariance for a set of symbols.
public struct PortfolioLabRiskModel: Equatable, Sendable {
    public var symbols: [String]
    public var expectedReturns: [Double]
    public var covariance: [[Double]]

    /// Shrinkage of off-diagonal covariances toward zero, and of each mean toward the cross-sectional mean.
    public static let covarianceShrinkage = 0.5
    public static let meanShrinkage = 0.5

    public init(symbols: [String], expectedReturns: [Double], covariance: [[Double]]) {
        self.symbols = symbols; self.expectedReturns = expectedReturns; self.covariance = covariance
    }

    public static func estimate(from panel: PortfolioLabReturnPanel,
                                expectation: PortfolioLabExpectation) -> PortfolioLabRiskModel {
        let rows = panel.returns, n = panel.symbols.count, count = Double(rows.count)
        let means = (0..<n).map { column in rows.reduce(0) { $0 + $1[column] } / count }
        var covariance = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in i..<n {
                let sum = rows.reduce(0) { $0 + ($1[i] - means[i]) * ($1[j] - means[j]) }
                let annual = 12 * sum / (count - 1) * (i == j ? 1 : 1 - covarianceShrinkage)
                covariance[i][j] = annual; covariance[j][i] = annual
            }
        }
        let annualMeans = means.map { 12 * $0 }
        let average = annualMeans.reduce(0, +) / Double(n)
        let expected = switch expectation {
        case .shrunkHistorical: annualMeans.map { (1 - meanShrinkage) * $0 + meanShrinkage * average }
        case .equal: Array(repeating: average, count: n)
        }
        return .init(symbols: panel.symbols, expectedReturns: expected, covariance: covariance)
    }

    /// The same model with a riskless cash asset appended.
    public func addingCash(symbol: String, annualRate: Double) -> PortfolioLabRiskModel {
        var grown = covariance.map { $0 + [0] }
        grown.append(Array(repeating: 0, count: symbols.count + 1))
        return .init(symbols: symbols + [symbol], expectedReturns: expectedReturns + [annualRate], covariance: grown)
    }

    public func volatility(of weights: [Double]) -> Double {
        var variance = 0.0
        for i in weights.indices { for j in weights.indices { variance += weights[i] * covariance[i][j] * weights[j] } }
        return max(variance, 0).squareRoot()
    }

    public func expectedReturn(of weights: [Double]) -> Double {
        zip(weights, expectedReturns).reduce(0) { $0 + $1.0 * $1.1 }
    }
}

/// How the person turns home currency into the fund's currency.
///
/// The defaults are typical published retail rates, not quotes. Bank conversion
/// is a spread on the rate; Norbert's Gambit buys an interlisted ETF in one
/// currency and sells it in the other, paying a small spread plus two commissions.
public struct PortfolioLabConversionMethod: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var spreadPercent: Double
    public var flatFee: Double

    public init(id: String, name: String, spreadPercent: Double, flatFee: Double) {
        self.id = id; self.name = name; self.spreadPercent = spreadPercent; self.flatFee = flatFee
    }

    public static let bank = Self(id: "bank", name: "Bank conversion", spreadPercent: 2.5, flatFee: 0)
    public static let brokerage = Self(id: "brokerage", name: "Brokerage auto-conversion", spreadPercent: 1.5, flatFee: 0)
    public static let norbertsGambit = Self(id: "norbertsGambit", name: "Norbert's Gambit", spreadPercent: 0.1, flatFee: 20)
    public static let standard: [Self] = [.bank, .brokerage, .norbertsGambit]

    /// Cost per unit of money converted, when converting `amount` in one go.
    public func costRate(converting amount: Double) -> Double {
        spreadPercent / 100 + (amount > 0 ? flatFee / amount : 0)
    }
}

public enum PortfolioLabCosts {
    /// Cost per unit of weight traded in each asset: conversion for foreign funds plus commission for any fund.
    public static func perUnit(assets: [PortfolioLabAsset], homeCurrency: String,
                               conversion: PortfolioLabConversionMethod, amount: Double,
                               commissionPercent: Double) -> [Double] {
        let conversionRate = conversion.costRate(converting: amount)
        return assets.map { asset in
            guard asset.kind != .cash else { return 0 }
            return commissionPercent / 100 + (asset.currency == homeCurrency ? 0 : conversionRate)
        }
    }
}
