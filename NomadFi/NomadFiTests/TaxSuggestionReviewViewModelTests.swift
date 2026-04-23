// TaxSuggestionReviewViewModelTests.swift
// NomadFi
//
// End-to-end coverage for the Phase 7 review view-model. Uses the
// full-schema container factory to keep delete/insert paths off
// the parallel-init crash class, and the suite is serialized per
// the project convention for SwiftData tests.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct TaxSuggestionReviewViewModelTests {

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

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func makeTuitionTransaction() -> Transaction {
        Transaction(
            merchantName: "UC Berkeley Tuition",
            originalAmount: -3_200,
            originalCurrency: .usd,
            date: Self.date(year: 2026, month: 4, day: 10),
            category: .education,
            jurisdiction: "US",
            notes: "Spring 2026 tuition",
            externalTransactionID: "tx-tuition-1"
        )
    }

    private func fetchTransactions(
        _ context: ModelContext
    ) throws -> [Transaction] {
        try context.fetch(
            FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
            )
        )
    }

    // MARK: - Refresh

    @Test("Refresh populates the queue from eligible transactions only")
    func refreshPopulatesQueueOnce() throws {
        let context = try makeContext()
        let tuition = makeTuitionTransaction()
        let transfer = Transaction(
            merchantName: "Internal Transfer",
            originalAmount: -200,
            date: Self.date(year: 2026, month: 4, day: 11),
            category: .transfer,
            externalTransactionID: "tx-transfer"
        )
        context.insert(tuition)
        context.insert(transfer)
        try context.save()

        let vm = TaxSuggestionReviewViewModel()
        vm.refresh(from: try fetchTransactions(context))

        #expect(vm.suggestions.count == 1)
        #expect(vm.suggestions.first?.proposedCategory == .tuition)
    }

    // MARK: - Dismiss

    @Test("Dismiss persists status and drops the row from the queue")
    func dismissMarksStatusAndRemovesFromQueue() throws {
        let context = try makeContext()
        let tuition = makeTuitionTransaction()
        context.insert(tuition)
        try context.save()

        let vm = TaxSuggestionReviewViewModel()
        var transactions = try fetchTransactions(context)
        vm.refresh(from: transactions)
        let suggestion = try #require(vm.suggestions.first)

        vm.dismiss(
            suggestion,
            in: context,
            transactions: transactions,
            now: Self.now
        )

        #expect(vm.suggestions.isEmpty)

        // Re-fetch from the database to verify persistence, not just
        // the VM's in-memory state.
        transactions = try fetchTransactions(context)
        let persisted = try #require(transactions.first)
        #expect(persisted.taxSuggestionStatusRawValue == TaxCategorySuggestionStatus.dismissed.rawValue)
        #expect(persisted.taxSuggestionLastReviewedAt == Self.now)
        #expect(persisted.taxDocument == nil)
        #expect(persisted.isTaxDeductible == false)

        // Dismissed rows must never resurface, even after another
        // refresh.
        vm.refresh(from: transactions)
        #expect(vm.suggestions.isEmpty)
    }

    // MARK: - Confirm

    @Test("Confirm creates a linked TaxDocument with the chosen category and marks status confirmed")
    func confirmCreatesLinkedTaxDocument() throws {
        let context = try makeContext()
        let tuition = makeTuitionTransaction()
        context.insert(tuition)
        try context.save()

        let vm = TaxSuggestionReviewViewModel()
        var transactions = try fetchTransactions(context)
        vm.refresh(from: transactions)
        let suggestion = try #require(vm.suggestions.first)

        let outcome = vm.confirm(
            suggestion,
            category: .tuition,
            in: context,
            transactions: transactions,
            now: Self.now
        )

        #expect(outcome == .createdDocument)
        #expect(vm.suggestions.isEmpty)

        transactions = try fetchTransactions(context)
        let persisted = try #require(transactions.first)
        #expect(persisted.taxSuggestionStatusRawValue == TaxCategorySuggestionStatus.confirmed.rawValue)
        #expect(persisted.taxSuggestionCategoryRawValue == TaxCategory.tuition.rawValue)
        // isTaxDeductible is never flipped implicitly — the user
        // decides that explicitly in TaxDocumentDetailView.
        #expect(persisted.isTaxDeductible == false)

        let doc = try #require(persisted.taxDocument)
        #expect(doc.taxCategoryRawValue == TaxCategory.tuition.rawValue)
        #expect(doc.merchantName == "UC Berkeley Tuition")
        #expect(doc.amount == 3_200)
        #expect(doc.taxYear == 2026)
        #expect(doc.isVerified == true)

        // And the row must not resurface.
        vm.refresh(from: transactions)
        #expect(vm.suggestions.isEmpty)
    }

    @Test("Confirming when a TaxDocument is already linked updates that document in place")
    func confirmUpdatesExistingLinkedDocument() throws {
        let context = try makeContext()
        let tuition = makeTuitionTransaction()
        context.insert(tuition)
        let existing = TaxDocument(
            merchantName: "UC Berkeley Tuition",
            amount: 3_200,
            currencyCode: .usd,
            documentDate: tuition.date,
            taxYear: 2026,
            jurisdiction: "US",
            taxCategory: .other,
            scannedAt: Self.now,
            isVerified: false,
            transaction: tuition
        )
        context.insert(existing)
        tuition.taxDocument = existing
        try context.save()

        let vm = TaxSuggestionReviewViewModel()
        let transactions = try fetchTransactions(context)
        // With a linked document the engine already excludes the row,
        // so the VM's queue is empty — but we still test the confirm
        // path directly because dismissed / ad-hoc flows may need it.
        vm.refresh(from: transactions)
        #expect(vm.suggestions.isEmpty)

        let suggestion = TaxCategorySuggestion(
            id: "tax-suggestion-tx-tuition-1",
            transactionID: "tx-tuition-1",
            merchantName: tuition.merchantName,
            amount: 3_200,
            currencyCode: .usd,
            transactionDate: tuition.date,
            jurisdiction: "US",
            existingTransactionCategory: .education,
            proposedCategory: .tuition,
            confidence: .high,
            reasons: []
        )

        let outcome = vm.confirm(
            suggestion,
            category: .tuition,
            in: context,
            transactions: transactions,
            now: Self.now
        )
        #expect(outcome == .linkedExistingDocument)

        let refreshed = try fetchTransactions(context)
        let doc = try #require(refreshed.first?.taxDocument)
        #expect(doc.taxCategoryRawValue == TaxCategory.tuition.rawValue)
        #expect(doc.isVerified == true)
    }
}
