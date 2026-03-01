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

    /// Maximum time to wait for a GPS fix before falling back gracefully.
    private static let locationTimeout: Duration = .seconds(10)

    func currentCountryCode() async throws -> String? {
        try await PerformanceMonitor.measure(.location, name: "Detect Country") {
            do {
                // Race location acquisition against a timeout to prevent
                // indefinite blocking when GPS/network is unavailable.
                return try await withThrowingTaskGroup(of: String?.self) { group in
                    group.addTask {
                        for try await update in CLLocationUpdate.liveUpdates() {
                            guard let location = update.location else { continue }

                            Self.logger.debug(
                                "Location acquired: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)"
                            )

                            return try await self.reverseGeocode(location)
                        }
                        return nil
                    }

                    group.addTask {
                        try await Task.sleep(for: Self.locationTimeout)
                        Self.logger.info("Location timeout after \(Self.locationTimeout)")
                        return nil
                    }

                    // Return whichever finishes first
                    for try await result in group {
                        group.cancelAll()
                        return result
                    }
                    return nil
                }
            } catch is CancellationError {
                return nil
            } catch {
                Self.logger.info(
                    "Location unavailable: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }
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
