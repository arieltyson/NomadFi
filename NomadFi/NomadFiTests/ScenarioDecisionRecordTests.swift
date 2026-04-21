// ScenarioDecisionRecordTests.swift
// NomadFi
//
// Round-trip coverage for the persisted Scenario 1 inputs using an
// in-memory SwiftData container. Verifies the `ScenarioDecisionRecord`
// inserts cleanly, retrieves by scenario ID, projects into
// `ScenarioDecisionState` without loss, and persists the linked
// Chase credit-card account relationship introduced in Phase 5.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct ScenarioDecisionRecordTests {

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

    /// In-memory container registering both `ScenarioDecisionRecord`
    /// and `Account` so the `chasePaymentAccount` relationship can be
    /// persisted and fetched.
    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ScenarioDecisionRecord.self, Account.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    /// Returns a credit-card account whose schedule clears the
    /// `CreditCardScheduleState.confirmed` check.
    private func insertConfirmedChaseAccount(
        in context: ModelContext
    ) -> Account {
        let account = Account(
            name: "Sample Rewards",
            institutionName: "Example Credit Union",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: Self.date(year: 2026, month: 4, day: 21)
        )
        context.insert(account)
        return account
    }

    // MARK: - Tests

    @Test("Blank record maps to a state that keeps the engine at review-cart-first")
    func blankRecordMapsToReviewCartFirst() throws {
        let context = try makeInMemoryContext()
        let record = ScenarioDecisionRecord(
            scenarioID: ScenarioDecisionRecord.scenario1ID
        )
        context.insert(record)
        try context.save()

        let state = ScenarioDecisionState(record: record)
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .reviewCartFirst)
    }

    @Test("Record round-trips through an in-memory container and preserves typed inputs")
    func recordRoundTripsThroughInMemoryContainer() throws {
        let context = try makeInMemoryContext()
        let statementClose = Self.date(year: 2026, month: 4, day: 28)

        let record = ScenarioDecisionRecord(
            scenarioID: ScenarioDecisionRecord.scenario1ID,
            cartShippingReviewed: true,
            airbnbPackageReceiptConfirmed: true,
            chaseAvailableCreditUSD: 500,
            chaseCurrentBalanceUSD: 50,
            chaseStatementCloseDate: statementClose,
            chaseWillPayBeforeStatementClose: true,
            wiseUSDBalanceUSD: 450,
            wiseCardAcceptedByAmazon: true
        )
        context.insert(record)
        try context.save()

        let scenarioID = ScenarioDecisionRecord.scenario1ID
        var descriptor = FetchDescriptor<ScenarioDecisionRecord>(
            predicate: #Predicate { $0.scenarioID == scenarioID }
        )
        descriptor.fetchLimit = 1

        let fetched = try context.fetch(descriptor).first
        #expect(fetched != nil)
        #expect(fetched?.cartShippingReviewed == true)
        #expect(fetched?.airbnbPackageReceiptConfirmed == true)
        #expect(fetched?.chaseAvailableCreditUSD == 500)
        #expect(fetched?.chaseCurrentBalanceUSD == 50)
        #expect(fetched?.chaseStatementCloseDate == statementClose)
        #expect(fetched?.chaseWillPayBeforeStatementClose == true)
        #expect(fetched?.wiseUSDBalanceUSD == 450)
        #expect(fetched?.wiseCardAcceptedByAmazon == true)
    }

    @Test("Linked Chase account relationship persists and round-trips")
    func chasePaymentAccountRoundTrips() throws {
        let context = try makeInMemoryContext()
        let account = insertConfirmedChaseAccount(in: context)
        let record = ScenarioDecisionRecord(
            scenarioID: ScenarioDecisionRecord.scenario1ID,
            chasePaymentAccount: account
        )
        context.insert(record)
        try context.save()

        let scenarioID = ScenarioDecisionRecord.scenario1ID
        var descriptor = FetchDescriptor<ScenarioDecisionRecord>(
            predicate: #Predicate { $0.scenarioID == scenarioID }
        )
        descriptor.fetchLimit = 1

        let fetched = try context.fetch(descriptor).first
        #expect(fetched != nil)
        #expect(fetched?.chasePaymentAccount?.persistentModelID == account.persistentModelID)
        #expect(fetched?.chasePaymentAccount?.name == "Sample Rewards")
    }

    @Test("fetchOrCreateScenario1Record returns the same record on subsequent calls")
    func fetchOrCreateIsIdempotent() throws {
        let context = try makeInMemoryContext()
        let first = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)
        let second = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)

        #expect(first.scenarioID == ScenarioDecisionRecord.scenario1ID)
        #expect(first.persistentModelID == second.persistentModelID)
    }

    @Test("Populated record with a linked, confirmed Chase account drives the Chase recommendation")
    func populatedRecordWithLinkedAccountDrivesChase() throws {
        let context = try makeInMemoryContext()
        let account = insertConfirmedChaseAccount(in: context)

        let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)
        record.cartShippingReviewed = true
        record.chaseAvailableCreditUSD = 500
        record.chaseCurrentBalanceUSD = 0
        record.chaseWillPayBeforeStatementClose = true
        record.chasePaymentAccount = account
        try context.save()

        let viewModel = ScenarioDecisionBriefViewModel(record: record)
        #expect(viewModel.decision.primaryPath == .chaseFreedomRiseUSD)

        // Entering a current balance surfaces a real projected utilization.
        record.chaseCurrentBalanceUSD = 50
        let projected = viewModel.decision.computedValues.projectedChaseUtilizationPercent ?? 0
        #expect(projected > 0.784)
        #expect(projected < 0.786)
    }

    @Test("Record without a linked Chase account blocks Chase even when numeric inputs are perfect")
    func noLinkedAccountBlocksChase() throws {
        let context = try makeInMemoryContext()
        let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)
        record.cartShippingReviewed = true
        record.chaseAvailableCreditUSD = 500
        record.chaseCurrentBalanceUSD = 0
        record.chaseWillPayBeforeStatementClose = true
        try context.save()

        let viewModel = ScenarioDecisionBriefViewModel(record: record)
        #expect(viewModel.decision.primaryPath != .chaseFreedomRiseUSD)
    }
}
