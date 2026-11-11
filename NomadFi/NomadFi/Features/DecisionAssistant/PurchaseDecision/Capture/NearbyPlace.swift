// NearbyPlace.swift
// NomadFi
//
// A place near the person that they might be paying at.

import Foundation

/// A nearby place reduced to what the purchase check needs: its name
/// and the kind of purchase it implies. Coordinates are never kept.
struct NearbyPlace: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: MerchantCategory
}
