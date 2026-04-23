// MerchantCategory.swift
// NomadFi
//
// User-picked category for the generic purchase decision engine.
// Intentionally coarse. NomadFi does not infer categories from
// merchant names — a bank statement that says "SQ *FOO-BAR" is not
// something NomadFi tries to classify on its own. The user picks;
// the engine reasons.
//
// Categories exist today only to prepare the engine for a future
// *verified* rewards model. They are not yet used for ranking.

import Foundation

/// Coarse category for a generic purchase. Sendable + Codable so
/// engine outputs and App Intent payloads can share a single value
/// type without a translation layer.
enum MerchantCategory: String, CaseIterable, Codable, Hashable, Sendable {

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

    // MARK: - Display

    /// User-facing label. Never marketing-y; never implies NomadFi
    /// has verified a rewards bonus for the category.
    var displayLabel: String {
        switch self {
        case .groceries: "Groceries"
        case .dining: "Dining"
        case .transit: "Transit"
        case .onlineShopping: "Online shopping"
        case .travel: "Travel"
        case .health: "Health"
        case .school: "School"
        case .subscriptions: "Subscriptions"
        case .utilities: "Utilities"
        case .general: "General purchase"
        }
    }

    /// SF Symbol paired with the label in the capture form picker.
    var systemImage: String {
        switch self {
        case .groceries: "basket"
        case .dining: "fork.knife"
        case .transit: "tram"
        case .onlineShopping: "cart"
        case .travel: "airplane"
        case .health: "heart.text.square"
        case .school: "graduationcap"
        case .subscriptions: "calendar.badge.clock"
        case .utilities: "bolt"
        case .general: "creditcard"
        }
    }

    /// VoiceOver phrasing read out in the picker.
    var accessibilityLabel: String {
        switch self {
        case .groceries: "Groceries purchase"
        case .dining: "Dining purchase"
        case .transit: "Transit purchase"
        case .onlineShopping: "Online shopping purchase"
        case .travel: "Travel purchase"
        case .health: "Health purchase"
        case .school: "School purchase"
        case .subscriptions: "Subscription purchase"
        case .utilities: "Utilities purchase"
        case .general: "General purchase"
        }
    }

    /// Whether the category typically carries rewards-category
    /// nuance (groceries, dining, travel, transit, online shopping).
    /// Used by the engine to emit a single "rewards not verified"
    /// checklist entry — never to rank or pick.
    var isRewardsSensitive: Bool {
        switch self {
        case .groceries, .dining, .transit, .onlineShopping, .travel:
            true
        case .health, .school, .subscriptions, .utilities, .general:
            false
        }
    }
}
