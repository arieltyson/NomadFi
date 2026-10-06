// AccountManagementTests.swift
// NomadFi
//
// Pins the Settings account lists: search and order, select-all,
// confirm-before-delete with cascade, and bulk clearing of credit-card
// calendars.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct AccountManagementTests {

    // MARK: - Listing

    @Test("Accounts sort by institution, then name, and search either")
    func listingOrderAndSearch() {
        let accounts = [
            account("Savings", at: "TD"),
            account("Chequing", at: "CIBC"),
            account("Rewards", at: "CIBC"),
        ]

        #expect(AccountListing.visible(accounts, matching: "").map(\.name) == ["Chequing", "Rewards", "Savings"])
        #expect(AccountListing.visible(accounts, matching: "cibc").map(\.name) == ["Chequing", "Rewards"])
        #expect(AccountListing.visible(accounts, matching: " sav ").map(\.name) == ["Savings"])
    }

    @Test("Select All selects every visible account, then clears")
    func selectAllToggles() throws {
        let context = try makeContext()
        let accounts = [account("A", at: "X"), account("B", at: "Y")]
        accounts.forEach(context.insert)
        let viewModel = AccountListViewModel()

        viewModel.toggleSelectAll(in: accounts)
        #expect(viewModel.isAllSelected(in: accounts))

        viewModel.toggleSelectAll(in: accounts)
        #expect(viewModel.selection.isEmpty)
    }

    // MARK: - Deletion

    @Test("Nothing is deleted until confirmed; confirming deletes the selection and its transactions")
    func deletionConfirmsAndCascades() throws {
        let context = try makeContext()
        let keep = account("Keep", at: "Bank")
        let remove = account("Remove", at: "Bank")
        context.insert(keep)
        context.insert(remove)
        let transaction = Transaction(merchantName: "Coffee", originalAmount: 4)
        context.insert(transaction)
        transaction.account = remove
        try context.save()

        let viewModel = AccountListViewModel()
        viewModel.selection = [remove.persistentModelID]
        viewModel.requestDeletionOfSelection(from: [keep, remove])

        #expect(viewModel.isConfirmingDeletion)
        #expect(viewModel.deletionTitle == "Delete Account?")
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 2)

        viewModel.confirmDeletion(in: context)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.map(\.name) == ["Keep"])
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(viewModel.selection.isEmpty)
    }

    @Test("Deleting several names how many")
    func pluralTitle() {
        let viewModel = AccountListViewModel()
        viewModel.requestDeletion(of: [account("A", at: "X"), account("B", at: "X"), account("C", at: "X")])
        #expect(viewModel.deletionTitle == "Delete 3 Accounts?")
    }

    // MARK: - Credit Card Calendar

    @Test("The calendar lists credit cards only")
    func calendarListsCards() {
        let viewModel = CreditCardCalendarViewModel()
        let cards = viewModel.visibleCards([account("Chequing", at: "X"), card("Visa", closing: .now)])
        #expect(cards.map(\.name) == ["Visa"])
    }

    @Test("Clearing removes every date from the selected cards only")
    func clearingSelectedCards() throws {
        let context = try makeContext()
        let cleared = card("Visa", closing: .now)
        let kept = card("Amex", closing: .now)
        context.insert(cleared)
        context.insert(kept)

        let viewModel = CreditCardCalendarViewModel()
        viewModel.selection = [cleared.persistentModelID]
        viewModel.requestClearOfSelection(from: [cleared, kept])
        #expect(viewModel.isConfirmingClear)
        #expect(cleared.statementClosingDate != nil)

        viewModel.confirmClear(in: context)

        #expect(CreditCardSchedule(account: cleared) == CreditCardSchedule())
        #expect(kept.statementClosingDate != nil)
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: NomadFiSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func account(_ name: String, at institution: String) -> Account {
        Account(name: name, institutionName: institution, accountType: .checking, currencyCode: .cad, jurisdiction: "CA")
    }

    private func card(_ name: String, closing: Date) -> Account {
        Account(
            name: name,
            institutionName: "Issuer",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA",
            statementPeriodStartDate: closing,
            statementClosingDate: closing,
            paymentDueDate: closing
        )
    }
}
