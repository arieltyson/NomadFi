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
struct ExchangeRateSnapshot: Sendable {
    let baseCurrency: CurrencyCode
    let targetCurrency: CurrencyCode
    let rate: Double
    let fetchedAt: Date
}
