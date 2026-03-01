// LiveExchangeRateService.swift
// NomadFi
//
// Fetches real-time FX rates from a free open exchange rate API.
// Uses ephemeral URLSession for privacy — no financial data cached to disk.

import Foundation
import OSLog

/// Live implementation of ``ExchangeRateService`` fetching real-time
/// mid-market exchange rates from an open API.
///
/// Uses cross-rate derivation from a single USD-based fetch to minimize
/// API calls while supporting all NomadFi currency pairs.
/// Falls back gracefully when the network is unavailable.
struct LiveExchangeRateService: ExchangeRateService {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "ExchangeRate")

    /// Base URL for the open exchange rate API (free, no API key required).
    private static let baseURL = URL(string: "https://open.er-api.com/v6/latest/")!

    /// Ephemeral session — no financial response data persisted to disk.
    /// Uses ``CertificatePinningDelegate`` for strict TLS trust evaluation.
    private let session: URLSession

    /// Retained delegate for the URLSession lifetime.
    private let pinningDelegate = CertificatePinningDelegate()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = true
        session = URLSession(
            configuration: configuration,
            delegate: pinningDelegate,
            delegateQueue: nil
        )
    }

    func fetchRate(base: CurrencyCode, target: CurrencyCode) async throws -> Double {
        if base == target { return 1.0 }

        let response = try await fetchRatesResponse(for: base)

        guard let rate = response.rates[target.rawValue] else {
            Self.logger.error("Rate not found for \(base.rawValue, privacy: .public) → \(target.rawValue, privacy: .public)")
            throw ExchangeRateServiceError.invalidResponse
        }

        return rate
    }

    func fetchAllRates(for currencies: [CurrencyCode]) async throws -> [ExchangeRateSnapshot] {
        guard currencies.count >= 2 else { return [] }

        // Fetch USD-based rates, then derive cross-rates for all pairs.
        // This minimizes API calls to a single request regardless of pair count.
        let response = try await PerformanceMonitor.measure(.network, name: "API Fetch Rates") {
            try await fetchRatesResponse(for: .usd)
        }
        let now = Date.now

        var snapshots: [ExchangeRateSnapshot] = []

        for base in currencies {
            for target in currencies where base != target {
                guard let baseToUSD = response.rates[base.rawValue],
                      let targetToUSD = response.rates[target.rawValue],
                      baseToUSD > 0
                else { continue }

                let crossRate = targetToUSD / baseToUSD
                snapshots.append(ExchangeRateSnapshot(
                    baseCurrency: base,
                    targetCurrency: target,
                    rate: crossRate,
                    fetchedAt: now
                ))
            }
        }

        Self.logger.info("Fetched \(snapshots.count) cross-rates for \(currencies.count) currencies")
        return snapshots
    }
}

// MARK: - Private Helpers

private extension LiveExchangeRateService {

    func fetchRatesResponse(for base: CurrencyCode) async throws -> ExchangeRateAPIResponse {
        let url = Self.baseURL.appending(path: base.rawValue)

        Self.logger.debug("Fetching rates from \(url.absoluteString, privacy: .public)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 429:
            Self.logger.warning("Rate limited by exchange rate API")
            throw ExchangeRateServiceError.rateLimited
        default:
            Self.logger.error("HTTP \(httpResponse.statusCode) from exchange rate API")
            throw ExchangeRateServiceError.networkUnavailable
        }

        let decoded = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)

        guard decoded.result == "success" else {
            Self.logger.error("API returned non-success result: \(decoded.result, privacy: .public)")
            throw ExchangeRateServiceError.invalidResponse
        }

        return decoded
    }
}

// MARK: - API Response Model

/// The JSON structure returned by the open exchange rate API.
private struct ExchangeRateAPIResponse: Decodable, Sendable {
    let result: String
    let rates: [String: Double]
}
