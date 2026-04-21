// CreditCardScheduleTests.swift
// NomadFi
//
// Focused coverage for the credit-card statement calendar layer:
// schedule projection off `Account`, state transitions, date-order
// validation, and SwiftData round-trip through an in-memory container.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct CreditCardScheduleTests {

    // MARK: - Helpers

    /// Convenience date constructor used throughout the suite so every
    /// test date lines up on midnight UTC and comparisons stay stable.
    nonisolated private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Account.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: - Defaults

    @Test("A freshly constructed account has every schedule field nil")
    func defaultAccountHasNilSchedule() {
        let account = Account(
            name: "Sample",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        #expect(account.statementPeriodStartDate == nil)
        #expect(account.statementClosingDate == nil)
        #expect(account.paymentDueDate == nil)
        #expect(account.statementScheduleLastConfirmedAt == nil)

        let schedule = CreditCardSchedule(account: account)
        #expect(schedule.state == .missing)
        #expect(!schedule.isComplete)
        #expect(schedule.hasValidDateOrder)
    }

    @Test("Existing account construction still compiles without schedule parameters")
    func existingConstructionStillWorks() {
        let account = Account(
            name: "Checking",
            institutionName: "Example",
            accountType: .checking,
            currencyCode: .usd,
            balance: 250
        )
        #expect(account.balance == 250)
        #expect(account.statementPeriodStartDate == nil)
    }

    // MARK: - State transitions

    @Test("A partial schedule is reported as partial")
    func partialScheduleIsPartial() {
        let schedule = CreditCardSchedule(
            statementClosingDate: Self.date(year: 2026, month: 5, day: 1)
        )
        #expect(schedule.state == .partial)
    }

    @Test("A complete but unconfirmed schedule is partial, not confirmed")
    func completeButUnconfirmedIsPartial() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25)
        )
        #expect(schedule.isComplete)
        #expect(schedule.state == .partial)
    }

    @Test("A complete, confirmed, in-order schedule is confirmed")
    func completeConfirmedScheduleIsConfirmed() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            lastConfirmedAt: Self.date(year: 2026, month: 4, day: 21)
        )
        #expect(schedule.state == .confirmed)
        #expect(schedule.hasValidDateOrder)
    }

    // MARK: - Date-order validation

    @Test("Due date before closing date is flagged as needsAttention")
    func dueBeforeClosingNeedsAttention() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 4, day: 15)
        )
        #expect(!schedule.hasValidDateOrder)
        #expect(schedule.state == .needsAttention)
        #expect(schedule.dateOrderIssue != nil)
    }

    @Test("Closing date before or equal to period start is flagged")
    func closingBeforeStartNeedsAttention() {
        let schedule = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 28),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 1),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25)
        )
        #expect(!schedule.hasValidDateOrder)
        #expect(schedule.state == .needsAttention)
    }

    @Test("Partial schedules are never flagged for ordering")
    func partialSchedulesNeverFlagOrdering() {
        let onlyStart = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1)
        )
        #expect(onlyStart.hasValidDateOrder)

        let startAndDue = CreditCardSchedule(
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25)
        )
        #expect(startAndDue.hasValidDateOrder)
    }

    // MARK: - SwiftData round-trip

    @Test("A credit-card account persists and round-trips every schedule field")
    func creditCardScheduleRoundTrips() throws {
        let context = try makeInMemoryContext()

        let start = Self.date(year: 2026, month: 4, day: 1)
        let closing = Self.date(year: 2026, month: 4, day: 28)
        let due = Self.date(year: 2026, month: 5, day: 25)
        let confirmed = Self.date(year: 2026, month: 4, day: 21)

        let account = Account(
            name: "Sample Rewards",
            institutionName: "Example Credit Union",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            statementPeriodStartDate: start,
            statementClosingDate: closing,
            paymentDueDate: due,
            statementScheduleLastConfirmedAt: confirmed
        )
        context.insert(account)
        try context.save()

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.name == "Sample Rewards" }
        )
        let fetched = try context.fetch(descriptor).first
        #expect(fetched != nil)
        #expect(fetched?.statementPeriodStartDate == start)
        #expect(fetched?.statementClosingDate == closing)
        #expect(fetched?.paymentDueDate == due)
        #expect(fetched?.statementScheduleLastConfirmedAt == confirmed)

        let schedule = CreditCardSchedule(account: fetched ?? account)
        #expect(schedule.state == .confirmed)
    }

    // MARK: - View model

    @Test("Saving applies working values to the account and stamps last-updated")
    func viewModelSavePersistsValues() throws {
        let context = try makeInMemoryContext()
        let account = Account(
            name: "Working",
            institutionName: "Example",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        context.insert(account)

        let fixedNow = Self.date(year: 2026, month: 4, day: 21)
        let viewModel = CreditCardScheduleEditViewModel(
            account: account,
            clock: { fixedNow }
        )

        viewModel.hasStatementPeriodStartDate = true
        viewModel.statementPeriodStartWorkingDate = Self.date(year: 2026, month: 4, day: 1)
        viewModel.hasStatementClosingDate = true
        viewModel.statementClosingWorkingDate = Self.date(year: 2026, month: 4, day: 28)
        viewModel.hasPaymentDueDate = true
        viewModel.paymentDueWorkingDate = Self.date(year: 2026, month: 5, day: 25)
        viewModel.isMarkedAsConfirmed = true

        viewModel.save()

        #expect(account.statementPeriodStartDate == Self.date(year: 2026, month: 4, day: 1))
        #expect(account.statementClosingDate == Self.date(year: 2026, month: 4, day: 28))
        #expect(account.paymentDueDate == Self.date(year: 2026, month: 5, day: 25))
        #expect(account.statementScheduleLastConfirmedAt == fixedNow)
        #expect(account.lastUpdatedAt == fixedNow)
    }

    @Test("Clearing wipes schedule fields on the next save")
    func viewModelClearRemovesValues() {
        let account = Account(
            name: "Working",
            institutionName: "Example",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: Self.date(year: 2026, month: 4, day: 21)
        )

        let viewModel = CreditCardScheduleEditViewModel(
            account: account,
            clock: { Self.date(year: 2026, month: 4, day: 22) }
        )
        viewModel.clearAll()
        viewModel.save()

        #expect(account.statementPeriodStartDate == nil)
        #expect(account.statementClosingDate == nil)
        #expect(account.paymentDueDate == nil)
        #expect(account.statementScheduleLastConfirmedAt == nil)
    }

    @Test("Invalid ordering blocks canSave")
    func invalidOrderingBlocksSave() {
        let account = Account(
            name: "Working",
            institutionName: "Example",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US"
        )
        let viewModel = CreditCardScheduleEditViewModel(account: account)
        viewModel.hasStatementPeriodStartDate = true
        viewModel.statementPeriodStartWorkingDate = Self.date(year: 2026, month: 4, day: 1)
        viewModel.hasStatementClosingDate = true
        viewModel.statementClosingWorkingDate = Self.date(year: 2026, month: 4, day: 28)
        viewModel.hasPaymentDueDate = true
        viewModel.paymentDueWorkingDate = Self.date(year: 2026, month: 4, day: 15)

        #expect(!viewModel.canSave)
        #expect(viewModel.validationIssue != nil)
    }
}
