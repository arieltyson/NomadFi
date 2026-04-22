// DecisionAssistantIntentContext.swift
// NomadFi
//
// Thin bridge between App Intents and the Decision Assistant's
// persistence + engine layers. Owns the "open a ModelContainer, fetch
// or create the Scenario 1 record, run the engine" dance so each
// intent stays small and stays off the SwiftData main-actor seams.

import Foundation
import SwiftData

/// Loads the Scenario 1 decision brief in a form the dialog
/// formatters (`DecisionAssistantIntentDialog`) can consume.
///
/// This is the single place App Intents cross into SwiftData. Every
/// intent calls the same entry point so the models registered in the
/// container and the interaction-detection logic stay consistent.
enum DecisionAssistantIntentContext {

    /// Opens a shared-store `ModelContainer`, resolves (or creates)
    /// the Scenario 1 record, and runs the deterministic engine.
    /// The returned context packages the engine output with the
    /// interaction flag so dialog copy can honour "no inputs yet"
    /// without a second round-trip.
    @MainActor
    static func loadAmazonArrivalBrief() throws -> DecisionAssistantIntentDialog.ScenarioBriefContext {
        // Register both models so the record's `chasePaymentAccount`
        // relationship can materialize when the engine projects state.
        let container = try ModelContainer(
            for: ScenarioDecisionRecord.self,
            Account.self
        )
        let context = container.mainContext

        let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(
            in: context
        )
        let state = ScenarioDecisionState(record: record)
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )

        return DecisionAssistantIntentDialog.ScenarioBriefContext(
            decision: decision,
            hasInteractedWithInputs: hasInteracted(with: state)
        )
    }

    /// Mirrors `DecisionAssistantViewModel.hasInteractedWithActiveDecision`
    /// without needing a view model. A record is "interacted with" the
    /// moment the user confirms any boolean or enters any numeric input
    /// — not when the record was created (SwiftData stamps `updatedAt`
    /// at insertion, so a timestamp check would be a false positive).
    static func hasInteracted(with state: ScenarioDecisionState) -> Bool {
        state.cartShippingReviewed
            || state.airbnbPackageReceiptConfirmed
            || state.chaseAvailableCreditUSD != nil
            || state.chaseCurrentBalanceUSD != nil
            || state.chaseWillPayBeforeStatementClose
            || state.wiseUSDBalanceUSD != nil
            || state.wiseCardAcceptedByAmazon
            || state.hasLinkedChaseAccount
    }
}
