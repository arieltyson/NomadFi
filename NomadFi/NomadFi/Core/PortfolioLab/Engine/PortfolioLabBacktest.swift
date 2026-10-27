import Foundation

public struct PortfolioLabValuePoint: Codable, Equatable, Sendable {
    public var month: String
    public var value: Double
}

public struct PortfolioLabBacktest: Equatable, Sendable {
    /// Portfolio value at the start (the month before the first return) and after each month.
    public var points: [PortfolioLabValuePoint]
    public var totalCost: Double
    public var initialCost: Double
    public var annualReturn: Double
    public var annualVolatility: Double
    public var maxDrawdown: Double
    public var endingValue: Double { points.last?.value ?? 0 }
}

/// Invests `amount` at the target weights, lets holdings drift with returns,
/// and trades back to target every `rebalanceEvery` months, paying `costs[i]`
/// per unit of value traded in asset `i`. Costs come out of the portfolio.
public enum PortfolioLabBacktester {
    public static func run(panel: PortfolioLabReturnPanel, weights: [Double], amount: Double,
                           costs: [Double], rebalanceEvery: Int = 12) -> PortfolioLabBacktest {
        var holdings = Array(repeating: 0.0, count: weights.count)
        let start = panel.months.first.flatMap(PortfolioLabCalendar.index(of:)).map { PortfolioLabCalendar.month(at: $0 - 1) } ?? ""
        var points = [PortfolioLabValuePoint(month: start, value: amount)]

        func rebalance(_ value: Double) -> Double {
            let cost = weights.indices.reduce(0) { $0 + costs[$1] * abs(weights[$1] * value - holdings[$1]) }
            holdings = weights.map { $0 * (value - cost) }
            return cost
        }

        let initialCost = rebalance(amount)
        var totalCost = initialCost
        for (index, row) in panel.returns.enumerated() {
            holdings = zip(holdings, row).map { $0 * (1 + $1) }
            var value = holdings.reduce(0, +)
            if rebalanceEvery > 0, (index + 1) % rebalanceEvery == 0, index + 1 < panel.returns.count {
                totalCost += rebalance(value)
                value = holdings.reduce(0, +)
            }
            points.append(.init(month: panel.months[index], value: value))
        }

        let values = points.map(\.value)
        let monthly = zip(values, values.dropFirst()).map { $1 / $0 - 1 }
        let years = Double(monthly.count) / 12
        let mean = monthly.reduce(0, +) / Double(max(monthly.count, 1))
        let variance = monthly.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(max(monthly.count - 1, 1))
        var peak = values.first ?? 0, drawdown = 0.0
        for value in values { peak = max(peak, value); drawdown = min(drawdown, value / peak - 1) }
        return .init(points: points, totalCost: totalCost, initialCost: initialCost,
                     annualReturn: years > 0 ? pow((values.last ?? amount) / amount, 1 / years) - 1 : 0,
                     annualVolatility: (variance * 12).squareRoot(), maxDrawdown: drawdown)
    }
}
