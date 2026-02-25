// LiveLocationService.swift
// NomadFi
//
// Provides one-shot country detection using CoreLocation for the
// Active Card recommendation engine.

import CoreLocation
import MapKit
import OSLog

/// Live implementation of ``LocationService`` using CoreLocation.
///
/// Detects the user's current country code via reverse geocoding
/// for the Active Card recommendation feature. Uses the modern
/// `CLLocationUpdate` async sequence for efficient, non-blocking access.
///
/// - Note: Requires `NSLocationWhenInUseUsageDescription` in Info.plist.
///   Returns `nil` gracefully when location is unavailable or denied.
struct LiveLocationService: LocationService {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "Location"
    )

    func currentCountryCode() async throws -> String? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let location = update.location else { continue }

                Self.logger.debug(
                    "Location acquired: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)"
                )

                return try await reverseGeocode(location)
            }
        } catch {
            // Graceful degradation — location unavailable does not break the app.
            // The Active Card feature simply won't show a recommendation.
            Self.logger.info(
                "Location unavailable: \(error.localizedDescription, privacy: .public)"
            )
        }

        return nil
    }
}

// MARK: - Private Helpers

extension LiveLocationService {

    /// Reverse geocodes a location to extract the ISO 3166-1 alpha-2 country code
    /// using MapKit's `MKReverseGeocodingRequest` and `MKAddressRepresentations`
    /// (iOS 26 replacement for deprecated `CLGeocoder` and `MKPlacemark`).
    fileprivate func reverseGeocode(_ location: CLLocation) async throws
        -> String?
    {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            Self.logger.info("Invalid coordinates for reverse geocoding")
            return nil
        }

        let mapItems = try await request.mapItems
        let countryCode = mapItems.first?.addressRepresentations?.region?.identifier

        Self.logger.info(
            "Country detected: \(countryCode ?? "unknown", privacy: .public)"
        )
        return countryCode
    }
}
