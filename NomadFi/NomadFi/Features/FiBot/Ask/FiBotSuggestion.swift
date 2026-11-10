// FiBotSuggestion.swift
// NomadFi
//
// Starter questions shown before the first one is asked.

import Foundation

/// A question someone can ask with one tap.
enum FiBotSuggestion: CaseIterable, Identifiable {
    case spending
    case subscriptions
    case cash

    var id: Self { self }

    /// The question, as it is shown and asked.
    var question: String {
        switch self {
        case .spending: String(localized: "How much have I spent this month?")
        case .subscriptions: String(localized: "What do my subscriptions cost?")
        case .cash: String(localized: "How much cash do I have?")
        }
    }

    var systemImage: String {
        switch self {
        case .spending: "cart"
        case .subscriptions: "arrow.triangle.2.circlepath"
        case .cash: "banknote"
        }
    }
}
