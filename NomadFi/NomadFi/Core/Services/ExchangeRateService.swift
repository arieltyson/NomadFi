// ExchangeRateService.swift
// NomadFi
//
// Protocol defining FX rate fetching operations.
// Concrete implementations handle network calls; mocks enable testing.

import Foundation

/// Defines the contract for fetching and caching exchange rates.
///
/// Implementations must be `Sendable` to safely cross concurrency boundaries,
/// as rate fetching is performed asynchronously from `@MainActor` view models.
protocol ExchangeRateService: Sendable {

    /// Fetches the latest exchange rate for a currency pair.
    /// - Parameters:
    ///   - base: The base currency (e.g., USD).
    ///   - target: The target currency (e.g., TTD).
    /// - Returns: The exchange rate (1 unit of base = rate units of target).
    func fetchRate(base: CurrencyCode, target: CurrencyCode) async throws -> Double

    /// Fetches rates for all pairs relevant to the given currencies.
    /// - Parameter currencies: The set of currencies to fetch cross-rates for.
    /// - Returns: An array of rate snapshots.
    func fetchAllRates(for currencies: [CurrencyCode]) async throws -> [ExchangeRateSnapshot]
}

/// A lightweight, non-persisted snapshot of an exchange rate.
///
/// Used for transferring rate data between the service layer and
/// view models before persisting to SwiftData.
///
/// Carries a ``SourceProvenance`` so the UI can honestly label whether a
/// rate came from an indicative prototype API, a sample dataset, or a
/// verified source — per the evidence hierarchy in `docs/README.md`.
struct ExchangeRateSnapshot: Sendable {
    let baseCurrency: CurrencyCode
    let targetCurrency: CurrencyCode
    let rate: Double
    let fetchedAt: Date
    let sourceProvenance: SourceProvenance

    init(
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        rate: Double,
        fetchedAt: Date,
        sourceProvenance: SourceProvenance
    ) {
        self.baseCurrency = baseCurrency
        self.targetCurrency = targetCurrency
        self.rate = rate
        self.fetchedAt = fetchedAt
        self.sourceProvenance = sourceProvenance
    }
}
