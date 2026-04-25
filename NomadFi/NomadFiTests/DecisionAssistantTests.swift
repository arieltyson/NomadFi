// DecisionAssistantTests.swift
// NomadFi
//
// Focused coverage for the Decision Assistant's pure catalog and
// for the parts of the view model that can be exercised without a
// SwiftUI host: identifier round-trip, history empty-state logic,
// and intent-driven brief presentation gating.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct DecisionAssistantTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ScenarioDecisionRecord.self,
            Account.self,
            JurisdictionProfile.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: - Catalog

    @Test("Catalog exposes at least the Amazon arrival-order decision")
    func catalogExposesAmazon() {
        let active = DecisionCatalog.activeDecision
        #expect(active?.id == .amazonArrivalOrder)
        #expect(active?.hasDeterministicEngine == true)
    }

    @Test("Catalog lookup round-trips via stable identifier")
    func catalogLookupRoundTrips() {
        for identity in DecisionCatalog.all {
            #expect(DecisionCatalog.decision(for: identity.id) == identity)
        }
    }

    @Test("All catalog entries today ship a deterministic engine")
    func catalogEntriesHaveDeterministicEngines() {
        for identity in DecisionCatalog.all {
            #expect(
                identity.hasDeterministicEngine,
                "Catalog entries without a deterministic engine must not appear until an intake scaffold hosts them instead."
            )
        }
    }

    // MARK: - View model

    @Test("Fresh view model exposes every catalog decision but reviewedDecisions is empty until evidence exists")
    func freshViewModelExposesActiveIdentity() {
        let viewModel = DecisionAssistantViewModel()
        // Scenario 1 stays the primary active decision for back-compat
        // callers; every deterministic decision (Amazon, Credit Timing,
        // and the generic Purchase Card Check) is a *catalog candidate*
        // for the history list — but `reviewedDecisions(...)` filters
        // that candidate set down to actually-reviewed evidence (none
        // yet on a fresh install).
        #expect(viewModel.activeDecision?.id == .amazonArrivalOrder)
        #expect(viewModel.activeDecisions.map(\.id) == [
            .amazonArrivalOrder,
            .creditTimingCheck,
            .purchaseCardCheck,
        ])
        #expect(viewModel.historicalDecisions.map(\.id) == [
            .amazonArrivalOrder,
            .creditTimingCheck,
            .purchaseCardCheck,
        ])
        #expect(viewModel.reviewedDecisions(reviewMarkers: []).isEmpty)
        #expect(!viewModel.hasInteractedWithActiveDecision)
        #expect(viewModel.activeDecisionOutstandingCheckCount == 0)
    }

    @Test("openActiveDecision is a no-op before bootstrap")
    func openActiveDecisionGuardedBeforeBootstrap() {
        let viewModel = DecisionAssistantViewModel()
        viewModel.openActiveDecision()
        #expect(!viewModel.isBriefPresented)
    }

    @Test("After bootstrap, openActiveDecision presents the brief")
    func openActiveDecisionPresentsAfterBootstrap() throws {
        let context = try makeContext()
        let viewModel = DecisionAssistantViewModel()
        viewModel.bootstrap(modelContext: context)
        viewModel.openActiveDecision()
        #expect(viewModel.isBriefPresented)
        #expect(viewModel.scenario1BriefViewModel != nil)
    }

    @Test("openDecision(.amazonArrivalOrder) routes to the active-decision path")
    func openDecisionRoutesAmazonToActive() throws {
        let context = try makeContext()
        let viewModel = DecisionAssistantViewModel()
        viewModel.bootstrap(modelContext: context)
        viewModel.openDecision(.amazonArrivalOrder)
        #expect(viewModel.isBriefPresented)
    }

    @Test("Bootstrap is idempotent — calling twice keeps the same record")
    func bootstrapIsIdempotent() throws {
        let context = try makeContext()
        let viewModel = DecisionAssistantViewModel()
        viewModel.bootstrap(modelContext: context)
        let first = viewModel.scenario1BriefViewModel
        viewModel.bootstrap(modelContext: context)
        #expect(viewModel.scenario1BriefViewModel === first)
    }

    @Test("Interaction flag flips once the user supplies any scenario input")
    func interactionFlagFlipsOnInput() throws {
        let context = try makeContext()
        let viewModel = DecisionAssistantViewModel()
        viewModel.bootstrap(modelContext: context)
        #expect(!viewModel.hasInteractedWithActiveDecision)

        viewModel.scenario1BriefViewModel?.record.cartShippingReviewed = true
        #expect(viewModel.hasInteractedWithActiveDecision)
    }
}
