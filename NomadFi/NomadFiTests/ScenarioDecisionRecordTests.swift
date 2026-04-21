// ScenarioDecisionRecordTests.swift
// NomadFi
//
// Round-trip coverage for the persisted Scenario 1 inputs using an
// in-memory SwiftData container. Verifies the `ScenarioDecisionRecord`
// inserts cleanly, retrieves by scenario ID, and projects into
// `ScenarioDecisionState` without loss.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct ScenarioDecisionRecordTests {

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: ScenarioDecisionRecord.self,
            configurations: configuration
        )
        return ModelContext(container)
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
        let statementClose = Date(timeIntervalSince1970: 1_750_000_000)

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

    @Test("fetchOrCreateScenario1Record returns the same record on subsequent calls")
    func fetchOrCreateIsIdempotent() throws {
        let context = try makeInMemoryContext()
        let first = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)
        let second = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)

        #expect(first.scenarioID == ScenarioDecisionRecord.scenario1ID)
        #expect(first.persistentModelID == second.persistentModelID)
    }

    @Test("Populated record drives the engine toward the Chase recommendation")
    func populatedRecordDrivesChaseRecommendation() throws {
        let context = try makeInMemoryContext()
        let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(in: context)
        record.cartShippingReviewed = true
        record.chaseAvailableCreditUSD = 500
        record.chaseCurrentBalanceUSD = 0
        record.chaseWillPayBeforeStatementClose = true
        try context.save()

        let viewModel = ScenarioDecisionBriefViewModel(record: record)
        #expect(viewModel.decision.primaryPath == .chaseFreedomRiseUSD)

        // Entering a current balance surfaces a real projected utilization.
        record.chaseCurrentBalanceUSD = 50
        let projected = viewModel.decision.computedValues.projectedChaseUtilizationPercent ?? 0
        #expect(projected > 0.784)
        #expect(projected < 0.786)
    }
}
