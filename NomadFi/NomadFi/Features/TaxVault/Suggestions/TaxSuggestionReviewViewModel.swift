// TaxSuggestionReviewViewModel.swift
// NomadFi
//
// Coordinates the Tax Vault suggestion review flow. Stays pure
// about policy — all banned-vocabulary copy lives in the engine /
// view; this type only orchestrates:
//   1. Building suggestions from in-scope transactions.
//   2. Applying a user's confirm / dismiss action to SwiftData.
//
// NomadFi never sets `Transaction.isTaxDeductible = true` here.
// The user decides deductibility explicitly inside
// `TaxDocumentDetailView`.

import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Outcome returned by `confirm(...)` so the UI can show the right
/// feedback without reading `modelContext` back.
enum TaxSuggestionConfirmOutcome: Sendable, Equatable {
    case createdDocument
    case linkedExistingDocument
    case failed
}

/// Observable VM for the review queue. The Tax Vault view holds a
/// single instance; `refresh(...)` re-runs the engine whenever the
/// underlying `[Transaction]` @Query changes.
@MainActor
@Observable
final class TaxSuggestionReviewViewModel {

    // MARK: - State

    /// Current review queue, already filtered to rows that are
    /// neither dismissed nor confirmed and whose transaction is not
    /// already linked to a tax document.
    var suggestions: [TaxCategorySuggestion] = []

    /// Suggestion the user is currently reviewing in the sheet. The
    /// UI binds the sheet presentation to `selection != nil`.
    var selection: TaxCategorySuggestion?

    /// Category the user has picked in the review sheet. Seeded
    /// from `selection.proposedCategory`, but the user can change
    /// it to any other `TaxCategory` before confirming.
    var draftCategory: TaxCategory = .other

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "TaxSuggestionReview"
    )

    // MARK: - Build

    /// Re-runs the engine against the supplied transactions and
    /// stores the resulting queue. Sorted by confidence desc then
    /// date desc so the strongest, freshest rows surface first.
    func refresh(from transactions: [Transaction]) {
        let engineOutput = TaxCategorySuggestionEngine.suggestions(for: transactions)
        suggestions = engineOutput.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.transactionDate > rhs.transactionDate
        }
        Self.logger.info("Tax suggestion queue rebuilt: \(self.suggestions.count) rows")
    }

    // MARK: - Selection

    /// Opens the review sheet for `suggestion`, seeding
    /// `draftCategory` with the proposed category so the sheet
    /// appears pre-filled.
    func select(_ suggestion: TaxCategorySuggestion) {
        selection = suggestion
        draftCategory = suggestion.proposedCategory
    }

    func clearSelection() {
        selection = nil
    }

    // MARK: - Actions

    /// Marks the suggestion's transaction as dismissed and updates
    /// the review queue. Never touches `isTaxDeductible`.
    func dismiss(
        _ suggestion: TaxCategorySuggestion,
        in modelContext: ModelContext,
        transactions: [Transaction],
        now: Date = .now
    ) {
        guard let transaction = matchingTransaction(
            for: suggestion,
            in: transactions
        ) else { return }

        transaction.taxSuggestionStatusRawValue = TaxCategorySuggestionStatus.dismissed.rawValue
        transaction.taxSuggestionLastReviewedAt = now
        transaction.taxSuggestionCategoryRawValue = suggestion.proposedCategory.rawValue

        saveAndRefresh(modelContext: modelContext, transactions: transactions)
    }

    /// Confirms the suggestion with the user-selected `category`.
    /// Creates (and links) a `TaxDocument` unless the transaction
    /// already has one, in which case the existing document's
    /// category is updated. Returns the outcome so the UI can
    /// decide what feedback to show.
    @discardableResult
    func confirm(
        _ suggestion: TaxCategorySuggestion,
        category: TaxCategory,
        in modelContext: ModelContext,
        transactions: [Transaction],
        now: Date = .now
    ) -> TaxSuggestionConfirmOutcome {
        guard let transaction = matchingTransaction(
            for: suggestion,
            in: transactions
        ) else { return .failed }

        let outcome: TaxSuggestionConfirmOutcome
        if let existing = transaction.taxDocument {
            existing.taxCategoryRawValue = category.rawValue
            existing.isVerified = true
            outcome = .linkedExistingDocument
        } else {
            let document = TaxDocument(
                merchantName: transaction.merchantName,
                amount: abs(transaction.originalAmount),
                currencyCode: transaction.originalCurrency ?? .usd,
                documentDate: transaction.date,
                taxYear: taxYear(for: transaction.date),
                jurisdiction: transaction.jurisdiction,
                taxCategory: category,
                extractedText: "",
                imageRelativePath: "",
                scannedAt: now,
                isVerified: true,
                transaction: transaction
            )
            modelContext.insert(document)
            transaction.taxDocument = document
            outcome = .createdDocument
        }

        transaction.taxSuggestionStatusRawValue = TaxCategorySuggestionStatus.confirmed.rawValue
        transaction.taxSuggestionLastReviewedAt = now
        transaction.taxSuggestionCategoryRawValue = category.rawValue

        saveAndRefresh(modelContext: modelContext, transactions: transactions)
        return outcome
    }

    // MARK: - Helpers

    private func matchingTransaction(
        for suggestion: TaxCategorySuggestion,
        in transactions: [Transaction]
    ) -> Transaction? {
        transactions.first { transaction in
            stableID(for: transaction) == suggestion.transactionID
        }
    }

    private func stableID(for transaction: Transaction) -> String {
        if let external = transaction.externalTransactionID,
           !external.isEmpty {
            return external
        }
        if let fingerprint = transaction.importFingerprint,
           !fingerprint.isEmpty {
            return fingerprint
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: transaction.date)
        let amountString = String(format: "%.2f", transaction.originalAmount)
        return "\(transaction.merchantName)|\(amountString)|\(dateString)"
    }

    private func taxYear(for date: Date) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: date)
    }

    private func saveAndRefresh(
        modelContext: ModelContext,
        transactions: [Transaction]
    ) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save tax suggestion state: \(error.localizedDescription)")
        }
        refresh(from: transactions)
        selection = nil
    }
}
