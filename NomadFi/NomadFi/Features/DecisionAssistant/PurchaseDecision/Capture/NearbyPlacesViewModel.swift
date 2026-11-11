// NearbyPlacesViewModel.swift
// NomadFi
//
// Loads the places around the person for the Near Me sheet.

import Foundation
import Observation

@MainActor
@Observable
final class NearbyPlacesViewModel {

    enum State: Equatable {
        case loading
        case loaded([NearbyPlace])
        case failed(NearbyPlacesError)
    }

    private(set) var state: State = .loading
    private let provider: any NearbyPlacesProviding

    init(provider: any NearbyPlacesProviding = MapKitNearbyPlacesProvider()) {
        self.provider = provider
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await provider.nearbyPlaces())
        } catch let error as NearbyPlacesError {
            state = .failed(error)
        } catch {
            state = .failed(.unavailable)
        }
    }
}
