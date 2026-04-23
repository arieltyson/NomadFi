// MerchantCategoryAppEnum.swift
// NomadFi
//
// App Intents adapter for ``MerchantCategory``. Kept separate from
// the core model so the domain enum never has to import `AppIntents`
// — the engine stays framework-free and the intent layer carries its
// own `AppEnum`-conforming mirror.
//
// One-to-one mapping with ``MerchantCategory`` so any future case
// added to the core enum requires a symmetric case here; Swift's
// exhaustive switching keeps that contract honest.

import AppIntents

/// App Intents adapter for the user-picked purchase category.
///
/// Surfaces the same ten categories as ``MerchantCategory`` inside
/// Siri and the Shortcuts app, with natural spoken display labels.
enum MerchantCategoryAppEnum: String, AppEnum {

    case groceries
    case dining
    case transit
    case onlineShopping
    case travel
    case health
    case school
    case subscriptions
    case utilities
    case general

    // MARK: - AppEnum

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        "Purchase category"

    static let caseDisplayRepresentations: [MerchantCategoryAppEnum: DisplayRepresentation] = [
        .groceries: "Groceries",
        .dining: "Dining",
        .transit: "Transit",
        .onlineShopping: "Online shopping",
        .travel: "Travel",
        .health: "Health",
        .school: "School",
        .subscriptions: "Subscriptions",
        .utilities: "Utilities",
        .general: "General purchase",
    ]
}

// MARK: - Bridging

extension MerchantCategoryAppEnum {

    /// Maps the App Intents adapter back to the core model enum.
    /// Exhaustive by construction so adding a case to either enum
    /// fails the build at this boundary until both sides agree.
    var merchantCategory: MerchantCategory {
        switch self {
        case .groceries: .groceries
        case .dining: .dining
        case .transit: .transit
        case .onlineShopping: .onlineShopping
        case .travel: .travel
        case .health: .health
        case .school: .school
        case .subscriptions: .subscriptions
        case .utilities: .utilities
        case .general: .general
        }
    }

    /// Mirror constructor — lets callers translate a core category
    /// into an intent-facing category when pre-seeding parameters
    /// from saved state.
    init(_ category: MerchantCategory) {
        switch category {
        case .groceries: self = .groceries
        case .dining: self = .dining
        case .transit: self = .transit
        case .onlineShopping: self = .onlineShopping
        case .travel: self = .travel
        case .health: self = .health
        case .school: self = .school
        case .subscriptions: self = .subscriptions
        case .utilities: self = .utilities
        case .general: self = .general
        }
    }
}
