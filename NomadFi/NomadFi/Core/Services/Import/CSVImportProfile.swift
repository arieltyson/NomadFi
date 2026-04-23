// CSVImportProfile.swift
// NomadFi
//
// Pure, Codable value type describing how a bank / issuer CSV
// export's columns map into NomadFi's transaction model.
//
// Profiles are header-driven rather than issuer-hardcoded: each
// profile carries a list of column *aliases* (case-insensitive
// header strings) for each logical field. That way a profile can
// match multiple variants of the same issuer's export, and the
// detector can score profiles by how well they match a given
// header row without any private fixture data.
//
// No network, no remote registry, no issuer scraping — the profile
// list is static and bundled with the app.

import Foundation

/// How an amount column encodes debit vs credit.
enum CSVAmountSignConvention: String, Codable, Sendable, Equatable {

    /// Debits are negative numbers, credits are positive. Common
    /// export convention.
    case negativeForDebit

    /// Debits are positive numbers, credits are negative. Seen on
    /// some statement-style exports (e.g., Wise sent/received when
    /// the user has chosen to view amounts as outflow-positive).
    case positiveForDebit

    /// File has separate debit and credit columns; the amount is
    /// read from whichever one is populated on the row.
    case separateDebitCreditColumns
}

/// Describes one CSV export shape. Entirely declarative — no code
/// branches per-issuer.
struct CSVImportProfile: Sendable, Equatable {

    /// Stable provenance label the resulting `Transaction` rows are
    /// tagged with.
    let source: TransactionImportSource

    /// Human-readable name shown in the preview UI. Never uses the
    /// issuer's trademarked name without "-like" to make clear
    /// NomadFi isn't claiming official integration.
    let displayName: String

    /// Header aliases (case-insensitive, trimmed) for each logical
    /// field. Order within an alias list expresses preference — the
    /// first alias that matches wins.
    let dateHeaderAliases: [String]
    let merchantHeaderAliases: [String]
    let amountHeaderAliases: [String]
    let debitHeaderAliases: [String]
    let creditHeaderAliases: [String]
    let currencyHeaderAliases: [String]
    let externalIDHeaderAliases: [String]

    /// Sign convention for the amount column(s).
    let amountSignConvention: CSVAmountSignConvention

    /// Ordered list of `DateFormatter` patterns to try when parsing
    /// the date column. First one that succeeds wins.
    let dateFormats: [String]

    /// Delimiter — a few profiles (rare) use tabs.
    let delimiter: CSVRowParser.Delimiter

    /// Default currency assumed when the file has no currency
    /// column. Callers can override per-import via the UI.
    let defaultCurrency: CurrencyCode
}

// MARK: - Header matching

extension CSVImportProfile {

    /// Scores this profile against a header row — higher is better.
    /// Each required logical field (`date`, `merchant`, `amount` or
    /// debit/credit pair) contributes up to 1 point; optional fields
    /// contribute 0.5. A zero score means this profile is unusable.
    func matchScore(for headers: [String]) -> Double {
        let normalized = headers.map(Self.normalizeHeader)
        var score = 0.0

        if matches(normalized, anyOf: dateHeaderAliases) { score += 1 }
        if matches(normalized, anyOf: merchantHeaderAliases) { score += 1 }

        switch amountSignConvention {
        case .separateDebitCreditColumns:
            if matches(normalized, anyOf: debitHeaderAliases) { score += 0.5 }
            if matches(normalized, anyOf: creditHeaderAliases) { score += 0.5 }
        case .negativeForDebit, .positiveForDebit:
            if matches(normalized, anyOf: amountHeaderAliases) { score += 1 }
        }

        if matches(normalized, anyOf: currencyHeaderAliases) { score += 0.25 }
        if matches(normalized, anyOf: externalIDHeaderAliases) { score += 0.25 }

        return score
    }

    /// Returns the column index in `headers` that matches `aliases`,
    /// or `nil` when none of the aliases is present.
    func columnIndex(
        in headers: [String],
        anyOf aliases: [String]
    ) -> Int? {
        let normalized = headers.map(Self.normalizeHeader)
        for alias in aliases.map(Self.normalizeHeader) {
            if let index = normalized.firstIndex(of: alias) {
                return index
            }
        }
        return nil
    }

    // MARK: - Private

    private func matches(_ headers: [String], anyOf aliases: [String]) -> Bool {
        let aliasesLower = Set(aliases.map(Self.normalizeHeader))
        return headers.contains { aliasesLower.contains($0) }
    }

    /// Trim whitespace, lowercase, and collapse internal runs. Keeps
    /// matching forgiving of the small header variations issuers
    /// ship between export formats.
    static func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
