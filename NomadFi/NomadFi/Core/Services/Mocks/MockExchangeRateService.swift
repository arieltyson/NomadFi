// MockExchangeRateService.swift
// NomadFi
//
// Mock implementation of ExchangeRateService for SwiftUI Previews
// and unit testing. Returns deterministic sample data.

import Foundation

/// A mock exchange rate service that returns hardcoded sample rates.
///
/// Rates are approximate mid-market values for the TT -> CA -> US corridor.
/// Use this in SwiftUI Previews and unit tests for deterministic behavior.
struct MockExchangeRateService: ExchangeRateService {

    /// Simulated network delay for realistic Preview behavior.
    var simulatedDelay: Duration = .milliseconds(300)

    /// Whether the service should simulate an error.
    var shouldFail: Bool = false

    func fetchRate(base: CurrencyCode, target: CurrencyCode) async throws -> Double {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw ExchangeRateServiceError.networkUnavailable
        }

        return Self.sampleRate(base: base, target: target)
    }

    func fetchAllRates(for currencies: [CurrencyCode]) async throws -> [ExchangeRateSnapshot] {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw ExchangeRateServiceError.networkUnavailable
        }

        var snapshots: [ExchangeRateSnapshot] = []
        let now = Date.now
        let provenance = SourceProvenance.sampleRates(accessedAt: now)

        for base in currencies {
            for target in currencies where base != target {
                let rate = Self.sampleRate(base: base, target: target)
                snapshots.append(ExchangeRateSnapshot(
                    baseCurrency: base,
                    targetCurrency: target,
                    rate: rate,
                    fetchedAt: now,
                    sourceProvenance: provenance
                ))
            }
        }

        return snapshots
    }

    // MARK: - Sample Data

    /// Returns a deterministic sample rate for a currency pair.
    static func sampleRate(base: CurrencyCode, target: CurrencyCode) -> Double {
        let usdRates: [CurrencyCode: Double] = [
            .usd: 1.0,
            .cad: 1.36,
            .ttd: 6.78,
            .gbp: 0.79,
            .eur: 0.92,
            .inr: 83.12,
            .ngn: 1550.0,
            .cny: 7.24,
        ]

        guard let baseToUSD = usdRates[base],
              let targetToUSD = usdRates[target]
        else { return 1.0 }

        return targetToUSD / baseToUSD
    }
}

/// Errors that can occur during exchange rate operations.
enum ExchangeRateServiceError: Error, LocalizedError, Sendable {
    case networkUnavailable
    case invalidResponse
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "Exchange rates are temporarily unavailable. Showing cached rates."
        case .invalidResponse: "Received an unexpected response from the exchange rate provider."
        case .rateLimited: "Too many requests. Please try again shortly."
        }
    }
}
