// NearbyPlacesProvider.swift
// NomadFi
//
// Finds the places around the person, once, when they ask.

import CoreLocation
import MapKit

/// Why nearby places could not be found.
enum NearbyPlacesError: Error, Equatable, Sendable {
    /// Location access is off for NomadFi.
    case locationDenied
    /// The device could not get a location, or Maps returned nothing usable.
    case unavailable
}

/// Lists places near the person.
protocol NearbyPlacesProviding: Sendable {
    func nearbyPlaces() async throws -> [NearbyPlace]
}

/// Uses one location fix and one Apple Maps search.
///
/// The location is requested only while this call runs, is sent only to
/// Apple Maps to find nearby places, and is discarded afterwards: results
/// keep a name and a category, never coordinates.
struct MapKitNearbyPlacesProvider: NearbyPlacesProviding {

    /// How far around the person to look, in metres. Small, so the list is
    /// the handful of places they could actually be standing in.
    static let searchRadius: CLLocationDistance = 120

    /// The most places listed.
    static let limit = 12

    func nearbyPlaces() async throws -> [NearbyPlace] {
        let location = try await currentLocation()
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: Self.searchRadius)
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch {
            throw NearbyPlacesError.unavailable
        }
        return response.mapItems
            .sorted { $0.location.distance(from: location) < $1.location.distance(from: location) }
            .prefix(Self.limit)
            .compactMap { item in
                guard let name = item.name, !name.isEmpty else { return nil }
                return NearbyPlace(
                    id: "\(name)|\(item.pointOfInterestCategory?.rawValue ?? "")",
                    name: name,
                    category: PlaceCategoryMapper.merchantCategory(for: item.pointOfInterestCategory)
                )
            }
    }

    /// One location fix, asking for When In Use access if it hasn't been decided.
    private func currentLocation() async throws -> CLLocation {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    throw NearbyPlacesError.locationDenied
                }
                if let location = update.location { return location }
            }
        } catch let error as NearbyPlacesError {
            throw error
        } catch {
            throw NearbyPlacesError.unavailable
        }
        throw NearbyPlacesError.unavailable
    }
}
