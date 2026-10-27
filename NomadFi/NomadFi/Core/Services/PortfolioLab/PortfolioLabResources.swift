// PortfolioLabResources.swift
// NomadFi
//
// The data Portfolio Lab ships with: the Bank of Canada FX snapshot the
// pipeline publishes, and illustrative fund prices for sample mode.

import Foundation

/// The pipeline's published snapshot (`services/portfolio-lab/pipeline`).
struct PortfolioLabFXSnapshot: Decodable, Sendable {

    struct Source: Decodable, Sendable {
        let name: String
        let url: URL
        let terms: URL
        let attribution: String
    }

    let generatedAt: String
    let source: Source
    let fx: PortfolioLabFXSeries
    let conversionMethods: [PortfolioLabConversionMethod]
}

/// Generated, not downloaded, prices for teaching. Always labeled illustrative.
struct PortfolioLabSampleMarket: Decodable, Sendable {
    let note: String
    let series: [PortfolioLabPriceSeries]
}

enum PortfolioLabResources {

    enum LoadError: Error {
        case missing(String)
    }

    static func fxSnapshot(in bundle: Bundle = .main) throws -> PortfolioLabFXSnapshot {
        try decode("fx-snapshot", in: bundle)
    }

    static func sampleMarket(in bundle: Bundle = .main) throws -> PortfolioLabSampleMarket {
        try decode("sample-market", in: bundle)
    }

    private static func decode<T: Decodable>(_ name: String, in bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoadError.missing(name)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
