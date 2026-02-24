// MockLocationService.swift
// NomadFi
//
// Mock implementation of LocationService for SwiftUI Previews and testing.

import Foundation

/// A mock location service that returns a configurable country code.
///
/// Defaults to "US" (San Francisco) to match the international student
/// scenario in Previews and tests.
struct MockLocationService: LocationService {

    var countryCode: String? = "US"
    var simulatedDelay: Duration = .milliseconds(100)
    var shouldFail: Bool = false

    func currentCountryCode() async throws -> String? {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw LocationServiceError.locationUnavailable
        }

        return countryCode
    }
}

/// Errors that can occur during location operations.
enum LocationServiceError: Error, LocalizedError, Sendable {
    case locationUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .locationUnavailable: "Unable to determine your current location."
        case .permissionDenied: "NomadFi needs location access to recommend the best card to use."
        }
    }
}
