// DecisionDraftInterpretationMissingField.swift
// NomadFi
//
// Discrete enum naming the structured fields the on-device
// interpreter could not extract from a natural-language scenario.
// The intake review screen surfaces these as "Add this before
// saving" reminders so the user is always the one who confirms a
// gap, not the model.

import Foundation

/// Structured fields the on-device interpreter could not pin down
/// from a free-form scenario. Surfaced verbatim by the review
/// screen — never a recommendation, never a guess.
enum DecisionDraftInterpretationMissingField: String, Sendable, Equatable, Hashable, CaseIterable {

    case kind
    case title
    case merchantName
    case locationText
    case amount
    case currencyCode
    case timingText

    /// Calm, factual label rendered next to the field on the
    /// review sheet.
    var displayLabel: String {
        switch self {
        case .kind: "Decision kind"
        case .title: "Short title"
        case .merchantName: "Merchant or counterparty"
        case .locationText: "City or context"
        case .amount: "Amount"
        case .currencyCode: "Currency"
        case .timingText: "Timing"
        }
    }
}
