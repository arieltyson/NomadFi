import Foundation
import Testing
@testable import PortfolioLabEngine

/// The Swift engine must reproduce the Python research reference
/// (`services/portfolio-lab/portfolio_lab/model.py`), which solves the same
/// problems with a different optimizer. Regenerate the fixtures with
/// `python -m portfolio_lab.parity` after changing either side.
struct PortfolioLabParityTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let resources = root.deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "NomadFi/NomadFi/Resources/PortfolioLab")

    private struct Fixtures: Decodable {
        struct Quality: Decodable { var symbol: String; var closes: [PortfolioLabClose]; var issues: [PortfolioLabDataIssue] }
        struct Optimizer: Decodable {
            var expectedReturns: [Double]; var covariance: [[Double]]; var costs: [Double]; var previous: [Double]
            var riskAversion: Double; var maxWeight: Double; var weights: [Double]; var objective: Double
        }
        struct Scenario: Decodable {
            var conversion: String; var weights: [Double]; var foreignShare: Double; var expectedReturn: Double
            var expectedVolatility: Double; var initialCost: Double; var totalCost: Double; var endingValue: Double
            var annualReturn: Double; var annualVolatility: Double; var maxDrawdown: Double
        }
        struct Engine: Decodable {
            var homeCurrency: String; var profile: PortfolioLabRiskProfile; var expectation: PortfolioLabExpectation
            var amount: Double; var months: [String]; var symbols: [String]; var scenarios: [Scenario]
        }
        var quality: Quality
        var optimizer: [Optimizer]
        var engine: [Engine]
    }
    private struct Snapshot: Decodable { var fx: PortfolioLabFXSeries; var conversionMethods: [PortfolioLabConversionMethod] }
    private struct Sample: Decodable { var series: [PortfolioLabPriceSeries] }

    private func load<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    private var fixtures: Fixtures { get throws { try load(Fixtures.self, Self.root.appending(path: "fixtures/parity.json")) } }

    private func close(_ a: Double, _ b: Double, _ tolerance: Double, _ label: String) {
        #expect(abs(a - b) <= tolerance * max(1, abs(b)), "\(label): swift \(a) vs python \(b)")
    }

    @Test func dataChecksMatch() throws {
        let quality = try fixtures.quality
        let asset = PortfolioLabAsset(symbol: quality.symbol, name: quality.symbol, currency: "USD", kind: .equity)
        #expect(PortfolioLabDataQuality.issues(in: .init(asset: asset, closes: quality.closes)) == quality.issues)
    }

    @Test func optimizerReachesTheReferenceOptimum() throws {
        for (index, item) in try fixtures.optimizer.enumerated() {
            let swift = try PortfolioLabOptimizer.optimize(expectedReturns: item.expectedReturns, covariance: item.covariance,
                                                           previous: item.previous, costs: item.costs,
                                                           riskAversion: item.riskAversion, maxWeight: item.maxWeight)
            #expect(swift.converged, "case \(index) did not converge")
            #expect(swift.objective >= item.objective - 1e-10, "case \(index): objective \(swift.objective) < \(item.objective)")
            for (a, b) in zip(swift.weights, item.weights) { close(a, b, 2e-6, "case \(index) weight") }
        }
    }

    @Test func engineScenariosMatchTheReference() throws {
        let snapshot = try load(Snapshot.self, Self.resources.appending(path: "fx-snapshot.json"))
        let sample = try load(Sample.self, Self.resources.appending(path: "sample-market.json"))
        #expect(snapshot.conversionMethods == PortfolioLabConversionMethod.standard)
        for item in try fixtures.engine {
            let result = try PortfolioLabEngine.run(.init(series: sample.series, fx: snapshot.fx, homeCurrency: item.homeCurrency,
                                                          amount: item.amount, profile: item.profile, expectation: item.expectation))
            let label = "\(item.homeCurrency) \(item.profile) \(item.expectation)"
            #expect(result.months == item.months, "\(label) months")
            #expect(result.assets.map(\.symbol) == item.symbols, "\(label) symbols")
            for (swift, python) in zip(result.comparisons, item.scenarios) {
                let tag = "\(label) \(python.conversion)"
                #expect(swift.conversion.id == python.conversion)
                for (a, b) in zip(swift.weights, python.weights) { close(a, b, 2e-6, "\(tag) weight") }
                close(swift.foreignShare, python.foreignShare, 1e-5, "\(tag) foreign share")
                close(swift.expectedReturn, python.expectedReturn, 1e-6, "\(tag) expected return")
                close(swift.expectedVolatility, python.expectedVolatility, 1e-5, "\(tag) volatility")
                close(swift.backtest.initialCost, python.initialCost, 1e-5, "\(tag) initial cost")
                close(swift.backtest.totalCost, python.totalCost, 1e-5, "\(tag) total cost")
                close(swift.backtest.endingValue, python.endingValue, 1e-5, "\(tag) ending value")
                close(swift.backtest.annualReturn, python.annualReturn, 1e-5, "\(tag) annual return")
                close(swift.backtest.annualVolatility, python.annualVolatility, 1e-5, "\(tag) annual volatility")
                close(swift.backtest.maxDrawdown, python.maxDrawdown, 1e-5, "\(tag) drawdown")
            }
        }
    }
}
