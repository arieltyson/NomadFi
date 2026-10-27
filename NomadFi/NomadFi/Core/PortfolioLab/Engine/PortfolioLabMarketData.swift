import Foundation

/// What a Portfolio Lab asset is, which decides whether it can carry trading costs.
public enum PortfolioLabAssetKind: String, Codable, CaseIterable, Sendable { case equity, bond, cash }

public struct PortfolioLabAsset: Codable, Hashable, Identifiable, Sendable {
    public var symbol: String
    public var name: String
    public var currency: String
    public var kind: PortfolioLabAssetKind
    public var id: String { symbol }
    public init(symbol: String, name: String, currency: String, kind: PortfolioLabAssetKind) {
        self.symbol = symbol; self.name = name; self.currency = currency; self.kind = kind
    }
}

/// One month-end value. `month` is written `YYYY-MM`.
public struct PortfolioLabClose: Codable, Equatable, Sendable {
    public var month: String
    public var close: Double
    public init(month: String, close: Double) { self.month = month; self.close = close }
}

/// Month-end closes for one asset, in the asset's own currency.
public struct PortfolioLabPriceSeries: Codable, Equatable, Sendable {
    public var asset: PortfolioLabAsset
    public var closes: [PortfolioLabClose]
    public init(asset: PortfolioLabAsset, closes: [PortfolioLabClose]) { self.asset = asset; self.closes = closes }
}

/// Month-end exchange rates: units of `quote` for one unit of `base` (CAD per USD).
public struct PortfolioLabFXSeries: Codable, Equatable, Sendable {
    public var base: String
    public var quote: String
    public var points: [PortfolioLabClose]
    public init(base: String, quote: String, points: [PortfolioLabClose]) {
        self.base = base; self.quote = quote; self.points = points
    }
}

public enum PortfolioLabError: Error, Equatable, Sendable {
    case noAssets
    case unsupportedCurrency(String)
    case insufficientHistory(months: Int)
    case infeasibleCap(maxWeight: Double, assets: Int)
}

/// Months as consecutive integers, so gaps and neighbours are simple arithmetic.
public enum PortfolioLabCalendar {
    public static func index(of month: String) -> Int? {
        let parts = month.split(separator: "-", omittingEmptySubsequences: false)
        guard month.count == 7, parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              let year = Int(parts[0]), let number = Int(parts[1]), (1...12).contains(number) else { return nil }
        return year * 12 + number - 1
    }

    public static func month(at index: Int) -> String {
        let year = index / 12, number = index % 12 + 1
        return String(year) + "-" + (number < 10 ? "0" : "") + String(number)
    }
}

// MARK: - Data quality

public enum PortfolioLabIssueKind: String, Codable, CaseIterable, Sendable {
    case duplicate, missing, nonpositive, jump, stale, unreadableMonth
}

public struct PortfolioLabDataIssue: Codable, Equatable, Sendable {
    public var symbol: String
    public var month: String
    public var kind: PortfolioLabIssueKind
    public init(symbol: String, month: String, kind: PortfolioLabIssueKind) {
        self.symbol = symbol; self.month = month; self.kind = kind
    }
}

/// Vendor checks run before any number reaches the optimizer.
///
/// A duplicate month keeps its first value. A missing month is one absent
/// between the series' first and last months. Non-positive or non-finite
/// closes are dropped. A jump is a month-over-month move larger than
/// `maxAbsReturn`. A close is stale from its `maxStale`-th repeat onward.
public enum PortfolioLabDataQuality {
    public static func issues(in series: PortfolioLabPriceSeries, maxAbsReturn: Double = 0.5,
                              maxStale: Int = 3) -> [PortfolioLabDataIssue] {
        let symbol = series.asset.symbol
        var issues: [PortfolioLabDataIssue] = []
        var seen = Set<Int>()
        var rows: [(index: Int, close: Double)] = []
        for close in series.closes {
            guard let index = PortfolioLabCalendar.index(of: close.month) else {
                issues.append(.init(symbol: symbol, month: close.month, kind: .unreadableMonth)); continue
            }
            guard seen.insert(index).inserted else {
                issues.append(.init(symbol: symbol, month: close.month, kind: .duplicate)); continue
            }
            rows.append((index, close.close))
        }
        rows.sort { $0.index < $1.index }

        if let first = rows.first?.index, let last = rows.last?.index {
            let present = Set(rows.map(\.index))
            for index in first...last where !present.contains(index) {
                issues.append(.init(symbol: symbol, month: PortfolioLabCalendar.month(at: index), kind: .missing))
            }
        }

        var previous: Double?
        var repeats = 0
        for row in rows {
            let month = PortfolioLabCalendar.month(at: row.index)
            guard row.close.isFinite, row.close > 0 else {
                issues.append(.init(symbol: symbol, month: month, kind: .nonpositive)); continue
            }
            if let previous {
                if abs(row.close / previous - 1) > maxAbsReturn {
                    issues.append(.init(symbol: symbol, month: month, kind: .jump))
                }
                repeats = row.close == previous ? repeats + 1 : 0
                if repeats >= maxStale { issues.append(.init(symbol: symbol, month: month, kind: .stale)) }
            }
            previous = row.close
        }
        return issues.sorted {
            ($0.month, order($0.kind)) < ($1.month, order($1.kind))
        }
    }

    /// Usable closes keyed by month index: first value per month, positive and finite.
    public static func usableCloses(_ closes: [PortfolioLabClose]) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for close in closes {
            guard let index = PortfolioLabCalendar.index(of: close.month), result[index] == nil else { continue }
            if close.close.isFinite, close.close > 0 { result[index] = close.close } else { result[index] = .nan }
        }
        return result.filter { !$0.value.isNaN }
    }

    private static func order(_ kind: PortfolioLabIssueKind) -> Int {
        PortfolioLabIssueKind.allCases.firstIndex(of: kind) ?? 0
    }
}

// MARK: - Returns in the home currency

/// Monthly returns, one row per month and one column per symbol.
/// `months[i]` is the month each return ends in.
public struct PortfolioLabReturnPanel: Equatable, Sendable {
    public var months: [String]
    public var symbols: [String]
    public var returns: [[Double]]
    public init(months: [String], symbols: [String], returns: [[Double]]) {
        self.months = months; self.symbols = symbols; self.returns = returns
    }
}

public enum PortfolioLabReturns {
    /// The minimum history the risk model accepts.
    public static let minimumMonths = 24

    /// Converts every series into the home currency and keeps only months where
    /// every asset (and the rate it needs) has a usable close in both that month and the one before.
    public static func homeCurrencyPanel(series: [PortfolioLabPriceSeries], fx: PortfolioLabFXSeries?,
                                         homeCurrency: String) throws -> PortfolioLabReturnPanel {
        guard !series.isEmpty else { throw PortfolioLabError.noAssets }
        let rates = fx.map { PortfolioLabDataQuality.usableCloses($0.points) } ?? [:]
        var valued: [[Int: Double]] = []
        for item in series {
            let closes = PortfolioLabDataQuality.usableCloses(item.closes)
            let currency = item.asset.currency
            if currency == homeCurrency { valued.append(closes); continue }
            guard let fx else { throw PortfolioLabError.unsupportedCurrency(currency) }
            let inverted: Bool
            switch (currency, homeCurrency) {
            case (fx.base, fx.quote): inverted = false
            case (fx.quote, fx.base): inverted = true
            default: throw PortfolioLabError.unsupportedCurrency(currency)
            }
            var home: [Int: Double] = [:]
            for (index, close) in closes {
                guard let rate = rates[index] else { continue }
                home[index] = inverted ? close / rate : close * rate
            }
            valued.append(home)
        }

        let common = valued.dropFirst().reduce(Set(valued[0].keys)) { $0.intersection($1.keys) }.sorted()
        var months: [String] = []
        var returns: [[Double]] = []
        for (previous, current) in zip(common, common.dropFirst()) where current == previous + 1 {
            months.append(PortfolioLabCalendar.month(at: current))
            returns.append(valued.map { $0[current]! / $0[previous]! - 1 })
        }
        guard months.count >= minimumMonths else { throw PortfolioLabError.insufficientHistory(months: months.count) }
        return .init(months: months, symbols: series.map(\.asset.symbol), returns: returns)
    }
}
