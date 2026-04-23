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

    // MARK: - Generic purchase bridge

    /// Opens a `ModelContainer` registering every `@Model` type the
    /// generic purchase engine or credit-timing engine touches through
    /// the `Account` graph, fetches all accounts, and runs
    /// `PurchaseDecisionEngine.decide` against `context`. Returns the
    /// engine output.
    ///
    /// Centralising the container registration here means voice
    /// callers never have to know which related types SwiftData needs
    /// to materialise the account relationships.
    @MainActor
    static func runPurchaseDecision(
        context: PurchaseContext,
        now: Date = .now
    ) throws -> PurchaseDecision {
        let accounts = try loadAccounts()
        return PurchaseDecisionEngine.decide(
            context: context,
            accounts: accounts,
            now: now
        )
    }

    // MARK: - Credit timing bridge

    /// Loads the user's saved accounts and runs
    /// `CreditTimingDecisionEngine.decide`. Returns the engine output.
    @MainActor
    static func runCreditTimingDecision(
        now: Date = .now
    ) throws -> CreditTimingDecision {
        let accounts = try loadAccounts()
        return CreditTimingDecisionEngine.decide(
            accounts: accounts,
            now: now
        )
    }

    // MARK: - Private

    /// Opens a shared-store `ModelContainer` registering the full
    /// account relationship graph (`Account`, `Transaction`,
    /// `Subscription`, `JurisdictionProfile`) and returns every
    /// `Account` row, sorted by institution + name for a stable read.
    @MainActor
    private static func loadAccounts() throws -> [Account] {
        let container = try ModelContainer(
            for: Account.self,
            Transaction.self,
            Subscription.self,
            JurisdictionProfile.self
        )
        let context = container.mainContext

        var descriptor = FetchDescriptor<Account>()
        descriptor.sortBy = [
            SortDescriptor(\.institutionName),
            SortDescriptor(\.name),
        ]
        return (try? context.fetch(descriptor)) ?? []
    }
}
