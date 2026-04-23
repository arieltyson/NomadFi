// TaxCategorySuggestionConfidence.swift
// NomadFi
//
// Named confidence buckets for tax-category suggestions. Kept
// deliberately coarse — NomadFi never treats a suggestion as
// "deductible" by itself, so three honest buckets are enough for
// the UI and voice surfaces to caveat appropriately.

import Foundation

/// How strong the signal behind a tax-category suggestion is.
///
/// Ordered so `suggestions.sorted { $0.confidence > $1.confidence }`
/// renders the strongest candidates first. Never implies the
/// underlying expense is deductible — only that NomadFi has more or
/// less text evidence behind the suggestion.
enum TaxCategorySuggestionConfidence: Int, Sendable, Comparable, CaseIterable {

    /// Transaction category + explicit keyword match on the
    /// merchant, normalized merchant, or notes text.
    case high = 2

    /// Transaction category matches but the merchant/notes text did
    /// not add an extra keyword. NomadFi still asks the user to
    /// confirm.
    case medium = 1

    /// Weak signal — income-style suggestions, treaty benefits, or
    /// capital gains from a single keyword. The UI always
    /// double-flags these as requiring user review.
    case low = 0

    // MARK: - Comparable

    static func < (
        lhs: TaxCategorySuggestionConfidence,
        rhs: TaxCategorySuggestionConfidence
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Display

    var displayLabel: String {
        switch self {
        case .high: "Strong signal"
        case .medium: "Moderate signal"
        case .low: "Weak signal — review carefully"
        }
    }

    /// VoiceOver phrasing. Never asserts deductibility.
    var accessibilityLabel: String {
        switch self {
        case .high:
            "Strong signal. NomadFi suggests a category but user review is still required."
        case .medium:
            "Moderate signal. Review before including in tax records."
        case .low:
            "Weak signal. Review carefully before including in tax records."
        }
    }

    var systemImage: String {
        switch self {
        case .high: "checkmark.seal"
        case .medium: "questionmark.circle"
        case .low: "exclamationmark.circle"
        }
    }
}
