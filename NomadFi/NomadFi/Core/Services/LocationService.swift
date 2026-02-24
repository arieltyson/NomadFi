// LocationService.swift
// NomadFi
//
// Protocol defining location-based operations for the
// Active Card recommendation engine.

import Foundation

/// Defines the contract for determining the user's current country.
///
/// Used by the Arbitrage Intelligence feature to recommend
/// the optimal payment source based on physical location.
protocol LocationService: Sendable {

    /// Returns the ISO 3166-1 alpha-2 country code for the user's current location.
    /// - Returns: A country code string (e.g., "US", "CA", "TT"), or `nil` if unavailable.
    func currentCountryCode() async throws -> String?
}
