// TaxCategorySuggestion.swift
// NomadFi
//
// Pure value type the review queue consumes. Carries just enough
// to render a row and open a review sheet without reaching back
// into SwiftData. Never asserts deductibility — NomadFi only
// *suggests*, the user confirms or dismisses.

import Foundation

/// A deterministic tax-category suggestion for a single
/// `Transaction`. Equality is by `id`, which ties back to the
/// underlying transaction's stable identity so the UI can diff
/// rows safely.
struct TaxCategorySuggestion: Sendable, Equatable, Identifiable {

    /// Stable identifier derived from the source transaction.
    let id: String

    /// Stable identity of the transaction the suggestion is for.
    /// Kept separate from `id` in case future surfaces need
    /// multiple suggestions per transaction.
    let transactionID: String

    /// Display-ready merchant name. Copied from
    /// `Transaction.merchantName` so the UI renders the casing the
    /// user recognises.
    let merchantName: String

    /// Positive magnitude of the transaction. Signs vary by import
    /// profile; the review queue always displays a magnitude.
    let amount: Double

    let currencyCode: CurrencyCode

    /// Date of the underlying transaction. Used for absolute-date
    /// labelling in the UI.
    let transactionDate: Date

    /// ISO jurisdiction tag carried through from the transaction.
    let jurisdiction: String

    /// Existing broad category on the transaction, if any. Shown to
    /// the user so they can see what NomadFi had before the
    /// suggestion.
    let existingTransactionCategory: TransactionCategory?

    /// The tax category NomadFi is suggesting.
    let proposedCategory: TaxCategory

    let confidence: TaxCategorySuggestionConfidence

    /// Ordered reasons. The UI renders at most three of these; tests
    /// pin the exact display text.
    let reasons: [TaxCategorySuggestionReason]

    // MARK: - Derived

    /// A short, single-line summary of the reasons for display in
    /// list rows. Never includes banned vocabulary — reasons are
    /// curated in the engine.
    var reasonSummary: String {
        reasons
            .prefix(2)
            .map(\.displayText)
            .joined(separator: " ")
    }
}
