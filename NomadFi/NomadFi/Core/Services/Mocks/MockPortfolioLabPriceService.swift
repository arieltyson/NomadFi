// MockPortfolioLabPriceService.swift
// NomadFi
//
// Offline stand-in for Tiingo in Previews and tests.

import Foundation

/// Answers with the bundled illustrative prices for whichever funds are requested.
struct MockPortfolioLabPriceService: PortfolioLabPriceService {

    var failure: PortfolioLabPriceServiceError?

    func monthlyCloses(for assets: [PortfolioLabAsset], since month: String) async throws -> [PortfolioLabPriceSeries] {
        if let failure { throw failure }
        let sample = try PortfolioLabResources.sampleMarket()
        return assets.compactMap { asset in sample.series.first { $0.asset.symbol == asset.symbol } }
    }
}
