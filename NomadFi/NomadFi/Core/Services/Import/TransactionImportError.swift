// TransactionImportError.swift
// NomadFi
//
// Per-row reason a CSV line couldn't become a `Transaction`. The
// preview surfaces one of these for every rejected row so the user
// understands why an import skipped something instead of guessing
// or silently discarding data.

import Foundation

/// User-facing reason an imported CSV row was rejected. Intentionally
/// explicit: the UI surfaces the raw enum case so power users can
/// diagnose malformed exports without digging into logs.
enum TransactionImportError: String, Error, Sendable, Equatable, CaseIterable {

    /// Row had fewer fields than the profile expected, or every
    /// field was empty after trimming.
    case emptyRow

    /// Amount field couldn't be parsed as a decimal number.
    case invalidAmount

    /// Row had neither a debit nor a credit column value on a
    /// profile that expects exactly one of them.
    case missingAmount

    /// Date field couldn't be parsed by any of the profile's date
    /// format candidates.
    case invalidDate

    /// The merchant / description field was empty after trimming.
    case missingMerchant

    /// Row's currency column doesn't match any `CurrencyCode` case
    /// NomadFi models — the row is rejected rather than silently
    /// coerced.
    case unsupportedCurrency

    /// Header row didn't name any of the columns the profile needs
    /// (specifically date, merchant, or amount).
    case profileColumnMissing

    // MARK: - Display

    var displayLabel: String {
        switch self {
        case .emptyRow: "Empty row"
        case .invalidAmount: "Invalid amount"
        case .missingAmount: "Missing amount"
        case .invalidDate: "Invalid date"
        case .missingMerchant: "Missing merchant"
        case .unsupportedCurrency: "Unsupported currency"
        case .profileColumnMissing: "Header column missing"
        }
    }
}
