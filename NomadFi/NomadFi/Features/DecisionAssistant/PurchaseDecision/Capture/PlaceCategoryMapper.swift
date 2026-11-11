// PlaceCategoryMapper.swift
// NomadFi
//
// Turns a Maps point-of-interest category into a purchase category.

import MapKit

/// Maps Apple Maps' point-of-interest categories onto the categories
/// card rewards are written in. Anything without a clear reward category
/// is a general purchase, which is the honest default.
enum PlaceCategoryMapper {

    static func merchantCategory(for category: MKPointOfInterestCategory?) -> MerchantCategory {
        switch category {
        case .foodMarket: .groceries
        case .restaurant, .cafe, .bakery, .brewery, .winery, .distillery, .nightlife: .dining
        case .publicTransport, .gasStation, .evCharger, .parking: .transit
        case .airport, .hotel, .carRental, .campground: .travel
        case .pharmacy, .hospital, .fitnessCenter: .health
        case .school, .university, .library: .school
        default: .general
        }
    }
}
