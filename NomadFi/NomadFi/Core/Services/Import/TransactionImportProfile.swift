// TransactionImportProfile.swift
// NomadFi
//
// Preset list of `CSVImportProfile` values — the header shapes we've
// seen on common issuer / wallet exports. Profile detection is purely
// header-driven: we score each preset against the user's header row
// and pick the highest-scoring one. No affiliation, no scraping, no
// private fixtures.
//
// Adding a future profile means adding a new entry in `allPresets` —
// no code change elsewhere.

import Foundation

/// Static catalog of CSV import profiles + a header-based detector.
enum TransactionImportProfile {

    // MARK: - Presets

    /// Shape seen on Chase personal statement exports: ISO-style
    /// date column, "Description" for merchant, separate "Debit" /
    /// "Credit" columns, optional transaction ID.
    static let chaseLike = CSVImportProfile(
        source: .csvChaseLike,
        displayName: "Chase-like export",
        dateHeaderAliases: ["transaction date", "posting date", "date"],
        merchantHeaderAliases: ["description", "merchant", "merchant name"],
        amountHeaderAliases: ["amount"],
        debitHeaderAliases: ["debit"],
        creditHeaderAliases: ["credit"],
        currencyHeaderAliases: ["currency", "currency code"],
        externalIDHeaderAliases: ["transaction id", "reference", "reference number"],
        amountSignConvention: .separateDebitCreditColumns,
        dateFormats: ["yyyy-MM-dd", "MM/dd/yyyy"],
        delimiter: .comma,
        defaultCurrency: .usd
    )

    /// CIBC-style export: "Date", "Description", single "Amount"
    /// column (negative = debit), optional reference number.
    static let cibcLike = CSVImportProfile(
        source: .csvCIBCLike,
        displayName: "CIBC-like export",
        dateHeaderAliases: ["date", "transaction date"],
        merchantHeaderAliases: ["description", "merchant"],
        amountHeaderAliases: ["amount", "cad"],
        debitHeaderAliases: [],
        creditHeaderAliases: [],
        currencyHeaderAliases: ["currency"],
        externalIDHeaderAliases: ["reference", "reference number"],
        amountSignConvention: .negativeForDebit,
        dateFormats: ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy"],
        delimiter: .comma,
        defaultCurrency: .cad
    )

    /// American Express Canada-style export: "Date" + "Description"
    /// + "Amount" (positive = you spent). A separate card-holder
    /// column is common but not required for import.
    static let amexCanadaLike = CSVImportProfile(
        source: .csvAmexCanadaLike,
        displayName: "Amex Canada-like export",
        dateHeaderAliases: ["date"],
        merchantHeaderAliases: ["description", "merchant"],
        amountHeaderAliases: ["amount"],
        debitHeaderAliases: [],
        creditHeaderAliases: [],
        currencyHeaderAliases: ["currency"],
        externalIDHeaderAliases: ["reference", "reference number"],
        amountSignConvention: .positiveForDebit,
        dateFormats: ["dd MMM yyyy", "dd/MM/yyyy", "yyyy-MM-dd"],
        delimiter: .comma,
        defaultCurrency: .cad
    )

    /// Wise-style balance statement: "Date", "Description",
    /// "Amount" (positive = inflow), "Currency" column.
    static let wiseLike = CSVImportProfile(
        source: .csvWiseLike,
        displayName: "Wise-like export",
        dateHeaderAliases: ["date", "transaction date"],
        merchantHeaderAliases: ["description", "merchant", "target name"],
        amountHeaderAliases: ["amount"],
        debitHeaderAliases: [],
        creditHeaderAliases: [],
        currencyHeaderAliases: ["currency"],
        externalIDHeaderAliases: ["transferwise id", "transaction id", "reference"],
        amountSignConvention: .negativeForDebit,
        dateFormats: ["yyyy-MM-dd", "dd-MM-yyyy"],
        delimiter: .comma,
        defaultCurrency: .usd
    )

    /// Generic fallback — tries the common header names from the
    /// presets above. Used when no named preset matches.
    static let generic = CSVImportProfile(
        source: .csvGeneric,
        displayName: "Generic CSV",
        dateHeaderAliases: ["date", "transaction date", "posting date"],
        merchantHeaderAliases: ["description", "merchant", "payee", "details"],
        amountHeaderAliases: ["amount"],
        debitHeaderAliases: ["debit"],
        creditHeaderAliases: ["credit"],
        currencyHeaderAliases: ["currency"],
        externalIDHeaderAliases: ["reference", "transaction id"],
        amountSignConvention: .negativeForDebit,
        dateFormats: ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "dd MMM yyyy"],
        delimiter: .comma,
        defaultCurrency: .usd
    )

    /// Every named preset in descending match-priority order. The
    /// detector prefers named profiles over the generic fallback
    /// when two profiles tie on score.
    static let namedPresets: [CSVImportProfile] = [
        chaseLike,
        cibcLike,
        amexCanadaLike,
        wiseLike,
    ]

    /// Full catalog — named presets plus the generic fallback.
    static let allPresets: [CSVImportProfile] = namedPresets + [generic]

    // MARK: - Detection

    /// Minimum score a named preset must reach before the detector
    /// considers it a match. Below this threshold we fall back to
    /// the generic profile so a partial match never silently
    /// mislabels the row provenance.
    static let namedProfileMatchThreshold: Double = 2.0

    /// Picks the best profile for a header row. Returns the generic
    /// profile when no named profile clears the threshold.
    static func detect(from headers: [String]) -> CSVImportProfile {
        let scored = namedPresets
            .map { ($0, $0.matchScore(for: headers)) }
            .filter { $0.1 >= namedProfileMatchThreshold }
            .sorted { $0.1 > $1.1 }
        if let best = scored.first {
            return best.0
        }
        return generic
    }
}
