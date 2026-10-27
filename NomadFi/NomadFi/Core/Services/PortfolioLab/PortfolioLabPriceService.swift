// PortfolioLabPriceService.swift
// NomadFi
//
// Month-end fund prices for Portfolio Lab's live mode.

import Foundation

/// Fetches month-end closes for funds, in each fund's own currency.
protocol PortfolioLabPriceService: Sendable {
    func monthlyCloses(for assets: [PortfolioLabAsset], since month: String) async throws -> [PortfolioLabPriceSeries]
}

enum PortfolioLabPriceServiceError: LocalizedError, Equatable {
    case missingToken
    case unauthorized
    case rateLimited
    case unavailable
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: String(localized: "Add your Tiingo API token to use real prices.")
        case .unauthorized: String(localized: "Tiingo didn't accept this token. Check it and try again.")
        case .rateLimited: String(localized: "Tiingo's free limit was reached. Try again later.")
        case .unavailable: String(localized: "Prices couldn't be loaded. Check your connection.")
        case .invalidResponse(let symbol): String(localized: "Tiingo returned unreadable prices for \(symbol).")
        }
    }
}

/// The funds live mode asks Tiingo for. Tiingo's end-of-day coverage is
/// US-listed securities, so live mode compares US-listed funds with
/// home-currency cash; Canadian-listed funds appear in sample mode only.
enum PortfolioLabLiveCatalog {
    static let funds: [PortfolioLabAsset] = [
        .init(symbol: "VTI", name: "US total stock market", currency: "USD", kind: .equity),
        .init(symbol: "VXUS", name: "International stocks", currency: "USD", kind: .equity),
        .init(symbol: "BND", name: "US bonds", currency: "USD", kind: .bond),
    ]
}
