// TaxCategorySuggestionStatus.swift
// NomadFi
//
// Persisted review state. `Transaction.taxSuggestionStatusRawValue`
// stores one of these raw values (or `nil` for "never surfaced").
// The engine skips any row whose status is already `dismissed` or
// `confirmed` so the review queue never resurfaces rows the user
// has already decided on.

import Foundation

/// Review state carried back by the Tax Vault suggestion queue.
enum TaxCategorySuggestionStatus: String, Sendable, Equatable, CaseIterable {

    /// NomadFi has surfaced the suggestion but the user has not
    /// acted yet. Equivalent to `nil` on the Transaction — both
    /// resurface in the review queue.
    case pending

    /// The user dismissed the suggestion. Never surfaced again.
    case dismissed

    /// The user confirmed the suggestion. Typically accompanied by
    /// a linked `TaxDocument`.
    case confirmed

    /// Convenience wrapper that treats missing raw values as
    /// `pending` — what the UI actually needs.
    static func from(rawValue: String?) -> TaxCategorySuggestionStatus {
        guard let rawValue,
              let parsed = TaxCategorySuggestionStatus(rawValue: rawValue)
        else {
            return .pending
        }
        return parsed
    }
}
