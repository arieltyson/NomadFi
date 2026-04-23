// TaxCategorySuggestionReason.swift
// NomadFi
//
// Short, user-facing reason text for a tax-category suggestion.
// Kept as a value type (not a free-form String) so tests can pin
// every reason NomadFi ever surfaces, and the copy-guard can sweep
// them for banned vocabulary in one place.

import Foundation

/// What signal produced a reason line. Never a legal claim — just
/// a description of the signal the engine saw.
enum TaxCategorySuggestionReasonKind: String, Sendable, Equatable, CaseIterable {

    /// The merchant or normalised-merchant string contained a
    /// keyword for this tax category.
    case merchantText

    /// The transaction's notes contained a keyword for this
    /// category.
    case notesText

    /// The transaction was already tagged with a matching generic
    /// category (e.g. `.education`, `.medical`).
    case transactionCategory

    /// The amount sign matched the category shape (e.g. a negative
    /// amount for an expense-like category).
    case amountSign

    /// The jurisdiction text hinted at the region (used only as a
    /// secondary reason, never as the main driver).
    case jurisdictionText
}

/// A single reason line. The UI concatenates the display text of
/// all reasons into a short summary.
struct TaxCategorySuggestionReason: Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let kind: TaxCategorySuggestionReasonKind
    let displayText: String
}
