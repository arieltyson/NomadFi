// TaxCategorySuggestionEngine.swift
// NomadFi
//
// Pure, deterministic engine that proposes a `TaxCategory` for a
// `Transaction` or returns `nil` when the evidence is too thin.
// Every rule is a literal keyword match + a transaction-category
// check — no ML, no network call, no LLM.
//
// Product invariants pinned in `TaxCategorySuggestionEngineTests`:
//
//   • Transfers, zero-amount rows, rows that already carry a
//     `TaxDocument`, and rows whose `taxSuggestionStatus` is
//     `dismissed` / `confirmed` never produce a suggestion.
//   • Expense-style categories require a negative `originalAmount`;
//     positive amounts with expense categories (refunds) are
//     skipped.
//   • Income-style categories (`.wages`, `.scholarshipIncome`,
//     `.treatyBenefits`) require an explicit textual keyword on top
//     of the income transaction category. They stay at `.low`
//     confidence so the UI double-flags them.
//   • `.capitalGains` requires an explicit "capital gains" match in
//     notes. Never inferred from amount alone.
//   • Confidence is conservative — `.high` requires both the
//     transaction category and a textual keyword match; `.medium`
//     is transaction category alone; `.low` is weak text-only
//     signal.
//   • The engine never mutates anything, including `isTaxDeductible`.
//     Confirmation and dismissal live in the review view-model.

import Foundation

/// Pure engine — call `suggest(for:)` for a single transaction or
/// `suggestions(for:)` for a batch.
enum TaxCategorySuggestionEngine {

    // MARK: - Public API

    /// Returns a suggestion for `transaction`, or `nil` when the
    /// evidence is too thin or the row has already been reviewed.
    @MainActor
    static func suggest(
        for transaction: Transaction
    ) -> TaxCategorySuggestion? {
        guard isEligible(transaction) else { return nil }

        let amount = transaction.originalAmount
        let magnitude = abs(amount)
        let category = transaction.category ?? .other
        let text = combinedText(for: transaction)
        let notesText = transaction.notes.lowercased()

        if let match = matchExpense(
            amount: amount,
            category: category,
            text: text
        ) {
            return materialise(match, for: transaction, magnitude: magnitude)
        }

        if let match = matchIncome(
            amount: amount,
            category: category,
            text: text
        ) {
            return materialise(match, for: transaction, magnitude: magnitude)
        }

        if let match = matchRare(notesText: notesText) {
            return materialise(match, for: transaction, magnitude: magnitude)
        }

        return nil
    }

    /// Batch helper. Surfaces only rows that produce a suggestion.
    @MainActor
    static func suggestions(
        for transactions: [Transaction]
    ) -> [TaxCategorySuggestion] {
        transactions.compactMap(suggest(for:))
    }

    // MARK: - Eligibility

    @MainActor
    private static func isEligible(_ transaction: Transaction) -> Bool {
        // Zero-amount rows have nothing to suggest about.
        if transaction.originalAmount == 0 { return false }

        // Transfers are internal moves — never tax-relevant.
        if transaction.category == .transfer { return false }

        // Already linked to a tax document — the user has handled it.
        if transaction.taxDocument != nil { return false }

        // Already reviewed (dismissed or confirmed) — never resurface.
        let status = TaxCategorySuggestionStatus.from(
            rawValue: transaction.taxSuggestionStatusRawValue
        )
        if status == .dismissed || status == .confirmed { return false }

        return true
    }

    // MARK: - Matching

    /// Result of a match attempt — only returned when a suggestion
    /// should actually be produced.
    private struct Match {
        let category: TaxCategory
        let confidence: TaxCategorySuggestionConfidence
        let reasons: [TaxCategorySuggestionReason]
    }

    @MainActor
    private static func matchExpense(
        amount: Double,
        category: TransactionCategory,
        text: String
    ) -> Match? {
        // Expense matches require a negative amount — positive
        // amounts with expense categories are refunds and should
        // not lead a user to claim them as expenses.
        guard amount < 0 else { return nil }

        if containsAny(text, tuitionKeywords) {
            return Match(
                category: .tuition,
                confidence: .high,
                reasons: [
                    Self.reason(.merchantText, "Merchant or notes mention tuition."),
                    Self.reason(.amountSign, "Transaction is an outflow."),
                ]
            )
        }

        if containsAny(text, textbookKeywords) {
            return Match(
                category: .textbooks,
                confidence: .high,
                reasons: [
                    Self.reason(.merchantText, "Merchant or notes mention textbooks or a bookstore."),
                    Self.reason(.amountSign, "Transaction is an outflow."),
                ]
            )
        }

        if containsAny(text, educationKeywords) {
            return Match(
                category: .education,
                confidence: confidence(forMatchedCategory: category == .education),
                reasons: educationReasons(hasCategory: category == .education)
            )
        }

        if category == .education {
            return Match(
                category: .education,
                confidence: .medium,
                reasons: [
                    Self.reason(.transactionCategory, "Transaction is already categorised as education."),
                ]
            )
        }

        if containsAny(text, medicalKeywords) {
            return Match(
                category: .medical,
                confidence: confidence(forMatchedCategory: category == .medical),
                reasons: medicalReasons(hasCategory: category == .medical)
            )
        }

        if category == .medical {
            return Match(
                category: .medical,
                confidence: .medium,
                reasons: [
                    Self.reason(.transactionCategory, "Transaction is already categorised as medical."),
                ]
            )
        }

        if containsAny(text, housingKeywords) {
            return Match(
                category: .housingExpense,
                confidence: confidence(forMatchedCategory: category == .housing),
                reasons: housingReasons(hasCategory: category == .housing)
            )
        }

        if category == .housing {
            return Match(
                category: .housingExpense,
                confidence: .medium,
                reasons: [
                    Self.reason(.transactionCategory, "Transaction is already categorised as housing."),
                ]
            )
        }

        return nil
    }

    @MainActor
    private static func matchIncome(
        amount: Double,
        category: TransactionCategory,
        text: String
    ) -> Match? {
        // Income-like matches require a positive inflow AND the
        // transaction to already be tagged `.income`. Anything
        // weaker is declined — wages-without-context is worse than
        // no suggestion.
        guard amount > 0, category == .income else { return nil }

        if containsAny(text, scholarshipKeywords) {
            return Match(
                category: .scholarshipIncome,
                confidence: .low,
                reasons: [
                    Self.reason(.notesText, "Notes or merchant mention a scholarship, fellowship, or grant."),
                    Self.reason(.transactionCategory, "Transaction is already categorised as income."),
                ]
            )
        }

        if containsAny(text, wageKeywords) {
            return Match(
                category: .wages,
                confidence: .low,
                reasons: [
                    Self.reason(.notesText, "Notes or merchant mention payroll, wages, or a pay stub."),
                    Self.reason(.transactionCategory, "Transaction is already categorised as income."),
                ]
            )
        }

        if containsAny(text, treatyKeywords) {
            return Match(
                category: .treatyBenefits,
                confidence: .low,
                reasons: [
                    Self.reason(.notesText, "Notes or merchant mention a treaty article or 1042 form."),
                    Self.reason(.transactionCategory, "Transaction is already categorised as income."),
                ]
            )
        }

        return nil
    }

    /// Rare categories that are text-driven regardless of the
    /// amount sign. Kept strictly to the user's notes so a
    /// coincidental merchant name can't spawn a treaty-benefits
    /// suggestion.
    @MainActor
    private static func matchRare(
        notesText: String
    ) -> Match? {
        if containsAny(notesText, capitalGainsNotesKeywords) {
            return Match(
                category: .capitalGains,
                confidence: .low,
                reasons: [
                    Self.reason(.notesText, "Notes mention capital gains."),
                ]
            )
        }

        if containsAny(notesText, treatyNotesKeywords) {
            return Match(
                category: .treatyBenefits,
                confidence: .low,
                reasons: [
                    Self.reason(.notesText, "Notes mention a treaty article or 1042 form."),
                ]
            )
        }

        return nil
    }

    // MARK: - Materialisation

    @MainActor
    private static func materialise(
        _ match: Match,
        for transaction: Transaction,
        magnitude: Double
    ) -> TaxCategorySuggestion {
        let transactionID = stableID(for: transaction)
        return TaxCategorySuggestion(
            id: "tax-suggestion-\(transactionID)",
            transactionID: transactionID,
            merchantName: transaction.merchantName,
            amount: magnitude,
            currencyCode: transaction.originalCurrency ?? .usd,
            transactionDate: transaction.date,
            jurisdiction: transaction.jurisdiction,
            existingTransactionCategory: transaction.category,
            proposedCategory: match.category,
            confidence: match.confidence,
            reasons: match.reasons
        )
    }

    @MainActor
    private static func stableID(for transaction: Transaction) -> String {
        if let external = transaction.externalTransactionID,
           !external.isEmpty {
            return external
        }
        if let fingerprint = transaction.importFingerprint,
           !fingerprint.isEmpty {
            return fingerprint
        }
        // Fallback: merchant|amount|ISO-date. Deterministic for the
        // same row without touching SwiftData identity.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: transaction.date)
        let amountString = String(format: "%.2f", transaction.originalAmount)
        return "\(transaction.merchantName)|\(amountString)|\(dateString)"
    }

    // MARK: - Confidence helpers

    private static func confidence(
        forMatchedCategory hasCategory: Bool
    ) -> TaxCategorySuggestionConfidence {
        hasCategory ? .high : .medium
    }

    private static func educationReasons(hasCategory: Bool) -> [TaxCategorySuggestionReason] {
        var reasons: [TaxCategorySuggestionReason] = [
            reason(.merchantText, "Merchant or notes mention education keywords.")
        ]
        if hasCategory {
            reasons.append(reason(.transactionCategory, "Transaction is already categorised as education."))
        }
        return reasons
    }

    private static func medicalReasons(hasCategory: Bool) -> [TaxCategorySuggestionReason] {
        var reasons: [TaxCategorySuggestionReason] = [
            reason(.merchantText, "Merchant or notes mention medical keywords.")
        ]
        if hasCategory {
            reasons.append(reason(.transactionCategory, "Transaction is already categorised as medical."))
        }
        return reasons
    }

    private static func housingReasons(hasCategory: Bool) -> [TaxCategorySuggestionReason] {
        var reasons: [TaxCategorySuggestionReason] = [
            reason(.merchantText, "Merchant or notes mention housing keywords.")
        ]
        if hasCategory {
            reasons.append(reason(.transactionCategory, "Transaction is already categorised as housing."))
        }
        return reasons
    }

    private static func reason(
        _ kind: TaxCategorySuggestionReasonKind,
        _ text: String
    ) -> TaxCategorySuggestionReason {
        TaxCategorySuggestionReason(
            id: "\(kind.rawValue)-\(text)",
            kind: kind,
            displayText: text
        )
    }

    // MARK: - Text signals

    @MainActor
    private static func combinedText(for transaction: Transaction) -> String {
        let parts: [String] = [
            transaction.merchantName,
            transaction.normalizedMerchantName ?? "",
            transaction.notes,
        ]
        return parts
            .joined(separator: " ")
            .lowercased()
    }

    private static func containsAny(
        _ text: String,
        _ keywords: [String]
    ) -> Bool {
        keywords.contains { !$0.isEmpty && text.contains($0) }
    }

    // Keyword lists intentionally overlap with `ReceiptCategorizer`
    // where the mappings are identical so both surfaces agree.
    private static let educationKeywords: [String] = [
        "university", "college", "campus", "registrar", "student",
        "academic", "semester", "enrollment", "course fee", "lab fee",
    ]

    private static let tuitionKeywords: [String] = [
        "tuition",
    ]

    private static let textbookKeywords: [String] = [
        "textbook", "bookstore", "chegg", "course materials",
        "lab manual", "study guide",
    ]

    private static let medicalKeywords: [String] = [
        "pharmacy", "hospital", "clinic", "medical", "prescription",
        "doctor", "dental", "optometry", "urgent care",
        "walgreens", "cvs", "rite aid",
    ]

    private static let housingKeywords: [String] = [
        "rent", "lease", "landlord", "apartment", "dormitory",
        "utilities", "electric bill", "gas bill", "water bill",
    ]

    private static let wageKeywords: [String] = [
        "payroll", "pay stub", "paystub", "wages", "salary",
        "compensation", "direct deposit",
    ]

    private static let scholarshipKeywords: [String] = [
        "scholarship", "fellowship", "grant", "stipend",
        "financial aid", "1042-s", "1042s",
    ]

    private static let treatyKeywords: [String] = [
        "treaty", "tax treaty", "withholding", "1042",
    ]

    private static let capitalGainsNotesKeywords: [String] = [
        "capital gains", "capital gain",
    ]

    private static let treatyNotesKeywords: [String] = [
        "treaty article", "tax treaty", "withholding", "1042",
    ]
}
