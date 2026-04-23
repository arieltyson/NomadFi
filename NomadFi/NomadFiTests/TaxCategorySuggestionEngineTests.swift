// TaxCategorySuggestionEngineTests.swift
// NomadFi
//
// Pure coverage for the Phase 7 suggestion engine. Transactions
// are built directly (no ModelContainer needed, matching the
// existing TransactionImportDeduperTests pattern) — the engine
// never writes to SwiftData, so these tests stay off the
// parallel-init race class.
//
// The product contract pinned here:
//   • Transfers, zero-amount rows, already-linked rows, and
//     already-reviewed rows never produce a suggestion.
//   • Expense signals only fire on negative amounts.
//   • Income signals require both a positive amount AND a textual
//     keyword; confidence is `.low` always.
//   • Confidence is conservative — `.high` requires text + category
//     agreement, `.medium` is category-only, `.low` is weak.
//   • No banned vocabulary in reasons or display copy.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct TaxCategorySuggestionEngineTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    nonisolated private static let now = date(year: 2026, month: 4, day: 22)

    private static func transaction(
        merchant: String = "Generic Merchant",
        amount: Double = -100,
        currency: CurrencyCode = .usd,
        category: TransactionCategory = .other,
        jurisdiction: String = "US",
        notes: String = "",
        externalID: String? = "tx-1",
        taxSuggestionStatus: TaxCategorySuggestionStatus? = nil,
        taxDocument: TaxDocument? = nil
    ) -> Transaction {
        Transaction(
            merchantName: merchant,
            originalAmount: amount,
            originalCurrency: currency,
            date: Self.date(year: 2026, month: 4, day: 10),
            category: category,
            jurisdiction: jurisdiction,
            notes: notes,
            externalTransactionID: externalID,
            taxSuggestionStatusRawValue: taxSuggestionStatus?.rawValue,
            taxDocument: taxDocument
        )
    }

    // MARK: - Ineligible rows

    @Test("Transfer rows never produce a suggestion")
    func transferRowsExcluded() {
        let tx = Self.transaction(
            merchant: "Internal Transfer",
            amount: -500,
            category: .transfer
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    @Test("Zero-amount rows produce no suggestion")
    func zeroAmountExcluded() {
        let tx = Self.transaction(
            merchant: "Nil Charge",
            amount: 0,
            category: .education
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    @Test("A transaction already linked to a TaxDocument does not resurface in the queue")
    func alreadyLinkedRowsExcluded() {
        let existingDoc = TaxDocument(
            merchantName: "University Bookstore",
            amount: 250,
            taxCategory: .textbooks
        )
        let tx = Self.transaction(
            merchant: "University Bookstore",
            amount: -250,
            category: .education,
            taxDocument: existingDoc
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    @Test("Dismissed rows never resurface")
    func dismissedRowsExcluded() {
        let tx = Self.transaction(
            merchant: "UC Berkeley Tuition",
            amount: -3_200,
            category: .education,
            notes: "Spring 2026 tuition",
            taxSuggestionStatus: .dismissed
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    @Test("Confirmed rows never resurface")
    func confirmedRowsExcluded() {
        let tx = Self.transaction(
            merchant: "UC Berkeley Tuition",
            amount: -3_200,
            category: .education,
            notes: "Spring 2026 tuition",
            taxSuggestionStatus: .confirmed
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    // MARK: - Expense category paths

    @Test("Tuition keyword produces a high-confidence .tuition suggestion")
    func tuitionExampleIsHighConfidence() throws {
        let tx = Self.transaction(
            merchant: "UC Berkeley Tuition",
            amount: -3_200,
            category: .education,
            notes: "Spring 2026 tuition"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .tuition)
        #expect(suggestion.confidence == .high)
        #expect(suggestion.amount == 3_200)
    }

    @Test("Textbook keyword produces a high-confidence .textbooks suggestion")
    func textbookExampleIsHighConfidence() throws {
        let tx = Self.transaction(
            merchant: "University Bookstore Chegg",
            amount: -120,
            category: .education,
            notes: "course textbooks"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .textbooks)
        #expect(suggestion.confidence == .high)
    }

    @Test("Medical keyword + .medical category yields high-confidence .medical suggestion")
    func medicalExampleIsHighConfidence() throws {
        let tx = Self.transaction(
            merchant: "CVS Pharmacy",
            amount: -48.50,
            category: .medical,
            notes: "prescription refill"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .medical)
        #expect(suggestion.confidence == .high)
    }

    @Test("Housing keyword + .housing category yields high-confidence .housingExpense")
    func housingExampleIsHighConfidence() throws {
        let tx = Self.transaction(
            merchant: "Oakview Apartments",
            amount: -1_850,
            category: .housing,
            notes: "April rent"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .housingExpense)
        #expect(suggestion.confidence == .high)
    }

    @Test("Category-only education (no text signal) is medium confidence")
    func categoryOnlyEducationIsMedium() throws {
        let tx = Self.transaction(
            merchant: "AA Plain Name",
            amount: -200,
            category: .education,
            notes: ""
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .education)
        #expect(suggestion.confidence == .medium)
    }

    @Test("Positive amount with an expense-like category (refund) is not suggested")
    func positiveExpenseAmountIsSkipped() {
        let tx = Self.transaction(
            merchant: "CVS Pharmacy refund",
            amount: 18.50,
            category: .medical
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    @Test("A merchant keyword without a matching transaction category still lifts to medium")
    func textOnlyMatchIsMedium() throws {
        let tx = Self.transaction(
            merchant: "Downtown Pharmacy",
            amount: -22,
            category: .other,
            notes: ""
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .medical)
        #expect(suggestion.confidence == .medium)
    }

    // MARK: - Income category paths

    @Test("Income + scholarship keyword yields low-confidence .scholarshipIncome")
    func scholarshipIsLowConfidence() throws {
        let tx = Self.transaction(
            merchant: "University Office",
            amount: 4_000,
            category: .income,
            notes: "Scholarship disbursement"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .scholarshipIncome)
        #expect(suggestion.confidence == .low)
    }

    @Test("Income + payroll keyword yields low-confidence .wages")
    func wagesIsLowConfidence() throws {
        let tx = Self.transaction(
            merchant: "ACME Corp Payroll",
            amount: 1_200,
            category: .income,
            notes: "biweekly pay stub"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .wages)
        #expect(suggestion.confidence == .low)
    }

    @Test("Income without any keyword evidence produces no suggestion")
    func incomeWithoutKeywordsIsSkipped() {
        let tx = Self.transaction(
            merchant: "Unknown Source",
            amount: 500,
            category: .income,
            notes: ""
        )
        #expect(TaxCategorySuggestionEngine.suggest(for: tx) == nil)
    }

    // MARK: - Rare / notes-driven paths

    @Test("Capital gains notes keyword produces low-confidence .capitalGains")
    func capitalGainsNotesAreLow() throws {
        let tx = Self.transaction(
            merchant: "Brokerage",
            amount: 340,
            category: .other,
            notes: "Short-term capital gains realised"
        )
        let suggestion = try #require(TaxCategorySuggestionEngine.suggest(for: tx))
        #expect(suggestion.proposedCategory == .capitalGains)
        #expect(suggestion.confidence == .low)
    }

    // MARK: - No auto-deductibility

    @Test("Generating a suggestion never sets isTaxDeductible on the transaction")
    func suggestionsDoNotMutateDeductibility() {
        let tx = Self.transaction(
            merchant: "UC Berkeley Tuition",
            amount: -3_200,
            category: .education,
            notes: "Spring 2026 tuition"
        )
        #expect(tx.isTaxDeductible == false)
        _ = TaxCategorySuggestionEngine.suggest(for: tx)
        #expect(tx.isTaxDeductible == false)
    }

    @Test("Generating a suggestion never flips the transaction's review status")
    func suggestionsDoNotMutateReviewStatus() {
        let tx = Self.transaction(
            merchant: "UC Berkeley Tuition",
            amount: -3_200,
            category: .education,
            notes: "Spring 2026 tuition"
        )
        #expect(tx.taxSuggestionStatusRawValue == nil)
        _ = TaxCategorySuggestionEngine.suggest(for: tx)
        #expect(tx.taxSuggestionStatusRawValue == nil)
    }

    // MARK: - Copy guard

    @Test("Every reason, confidence label, and status display the engine exposes avoids the banned tax vocabulary")
    func copyGuardOnSuggestionVocabulary() {
        let bannedPhrases: [String] = [
            "This is deductible",
            "deductible",
            "This qualifies",
            "qualifies",
            "You can claim this",
            "guaranteed",
            "approved",
            "tax advice",
        ]

        // Everything the engine surfaces in reason text.
        let fixtures: [(merchant: String, notes: String, amount: Double, category: TransactionCategory)] = [
            ("UC Berkeley Tuition", "Spring 2026 tuition", -3_200, .education),
            ("University Bookstore Chegg", "course textbooks", -120, .education),
            ("CVS Pharmacy", "prescription refill", -48.50, .medical),
            ("Oakview Apartments", "April rent", -1_850, .housing),
            ("ACME Corp Payroll", "biweekly pay stub", 1_200, .income),
            ("University Office", "Scholarship disbursement", 4_000, .income),
            ("Brokerage", "Short-term capital gains realised", 340, .other),
            ("AA Plain Name", "", -200, .education),
        ]

        var inspected: [String] = []
        for fixture in fixtures {
            let tx = Self.transaction(
                merchant: fixture.merchant,
                amount: fixture.amount,
                category: fixture.category,
                notes: fixture.notes
            )
            if let suggestion = TaxCategorySuggestionEngine.suggest(for: tx) {
                inspected.append(suggestion.reasonSummary)
                for reason in suggestion.reasons {
                    inspected.append(reason.displayText)
                }
            }
        }

        for confidence in TaxCategorySuggestionConfidence.allCases {
            inspected.append(confidence.displayLabel)
            inspected.append(confidence.accessibilityLabel)
        }

        // "Deductible" and "qualifies" can never appear. The engine
        // talks about signals, not tax conclusions.
        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in tax-suggestion copy: \(copy)"
                )
            }
        }
    }
}
