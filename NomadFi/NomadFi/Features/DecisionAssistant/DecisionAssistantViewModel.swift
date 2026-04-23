// DecisionAssistantViewModel.swift
// NomadFi
//
// Owns the Decision Assistant's persistent state across every
// deterministic engine:
//
//   - Scenario 1 (Amazon arrival order) — backed by
//     `ScenarioDecisionBriefViewModel` and a SwiftData record.
//   - Credit Timing — backed by the pure
//     `CreditTimingDecisionEngine`; no persistence of its own, the
//     user's `Account` rows are the source of truth.
//
// View logic stays here — the view stays a thin render.

import Foundation
import Observation
import OSLog
import SwiftData

/// Drives the Decision Assistant tab.
@MainActor
@Observable
final class DecisionAssistantViewModel {

    // MARK: - Catalog

    /// The primary active decision — currently Scenario 1 (Amazon
    /// arrival order). Kept for back-compat with callers that still
    /// address a single "active decision"; prefer ``activeDecisions``
    /// for new code.
    let activeDecision: DecisionIdentity?

    /// Every catalog decision with a deterministic engine, in catalog
    /// order. Each one renders its own hero card.
    let activeDecisions: [DecisionIdentity]

    /// Decisions that can appear in the history / previous list,
    /// regardless of whether they have a persisted record yet.
    let historicalDecisions: [DecisionIdentity]

    // MARK: - Per-engine state

    /// Brief view-model behind Scenario 1. Lazily materialised once
    /// the owning view hands the view model a `ModelContext` via
    /// ``bootstrap(modelContext:)``.
    private(set) var scenario1BriefViewModel: ScenarioDecisionBriefViewModel?

    /// Brief view-model behind the generic purchase decision. Same
    /// lazy-bootstrap pattern so the SwiftData record stays stable
    /// across view rebuilds.
    private(set) var purchaseDecisionBriefViewModel: PurchaseDecisionBriefViewModel?

    /// True when the Scenario 1 brief sheet is presented. Owned by
    /// the view model so Siri / App Intent deep links can flip it
    /// programmatically.
    var isBriefPresented: Bool = false

    /// True when the Credit Timing brief sheet is presented.
    var isCreditTimingBriefPresented: Bool = false

    /// True when the generic purchase-decision brief sheet is presented.
    var isPurchaseDecisionBriefPresented: Bool = false

    /// True when the decision-draft capture sheet is presented.
    /// Owned by the view model so the capture affordance on
    /// `NewDecisionScaffoldCard` can be driven through a tested
    /// `@Observable` surface instead of scattered `@State`.
    var isDraftFormPresented: Bool = false

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionAssistant"
    )

    init(
        activeDecision: DecisionIdentity? = DecisionCatalog.activeDecision,
        activeDecisions: [DecisionIdentity] = DecisionCatalog.all.filter(\.hasDeterministicEngine),
        historicalDecisions: [DecisionIdentity] = DecisionCatalog.historicalCandidates
    ) {
        self.activeDecision = activeDecision
        self.activeDecisions = activeDecisions
        self.historicalDecisions = historicalDecisions
    }

    // MARK: - Bootstrap

    /// Fetches or creates the deterministic engine records and
    /// wraps them in brief view-models. Safe to call more than once
    /// — each brief bootstraps once and stays stable across view
    /// rebuilds.
    func bootstrap(modelContext: ModelContext) {
        if scenario1BriefViewModel == nil {
            let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(
                in: modelContext
            )
            scenario1BriefViewModel = ScenarioDecisionBriefViewModel(record: record)
        }

        if purchaseDecisionBriefViewModel == nil {
            let record = PurchaseDecisionRecord.fetchOrCreateActiveRecord(
                in: modelContext
            )
            purchaseDecisionBriefViewModel = PurchaseDecisionBriefViewModel(record: record)
        }
    }

    // MARK: - Intents

    /// Opens the Scenario 1 brief. Currently the only catalog entry
    /// with an app-side sheet backed by a ``ScenarioDecisionRecord``;
    /// guards so Siri / intent-driven callers can't accidentally
    /// present an empty sheet.
    func openActiveDecision() {
        guard scenario1BriefViewModel != nil else {
            Self.logger.warning("openActiveDecision called before bootstrap completed")
            return
        }
        isBriefPresented = true
    }

    /// Presents the Credit Timing brief. No bootstrap required — the
    /// engine reads the `@Query<Account>` live from the view.
    func openCreditTimingBrief() {
        isCreditTimingBriefPresented = true
    }

    /// Presents the generic purchase-decision brief. The brief's
    /// view model must already be bootstrapped; guards so intent-
    /// driven callers don't open an empty sheet.
    func openPurchaseDecisionBrief() {
        guard purchaseDecisionBriefViewModel != nil else {
            Self.logger.warning("openPurchaseDecisionBrief called before bootstrap completed")
            return
        }
        isPurchaseDecisionBriefPresented = true
    }

    /// Opens a specific decision by identifier. Used by the history
    /// list and reserved for future App Intent deep links.
    func openDecision(_ id: DecisionID) {
        switch id {
        case .amazonArrivalOrder:
            openActiveDecision()
        case .creditTimingCheck:
            openCreditTimingBrief()
        case .purchaseCardCheck:
            openPurchaseDecisionBrief()
        }
    }

    /// Presents the decision-draft capture sheet. Tapped from the
    /// "Capture decision" button on ``NewDecisionScaffoldCard``.
    func presentDraftForm() {
        isDraftFormPresented = true
    }

    // MARK: - Summaries

    /// One-line summary for the hero row corresponding to `id`.
    /// The view passes the current `[Account]` so the Credit Timing
    /// summary stays in lockstep with the Decisions tab's live query.
    func summary(
        for id: DecisionID,
        accounts: [Account],
        now: Date = .now
    ) -> DecisionSummary {
        switch id {
        case .amazonArrivalOrder:
            return scenario1Summary()
        case .creditTimingCheck:
            return creditTimingSummary(accounts: accounts, now: now)
        case .purchaseCardCheck:
            return purchaseDecisionSummary(accounts: accounts, now: now)
        }
    }

    // MARK: - Scenario 1 helpers (kept for back-compat)

    /// Human-readable ruling string for Scenario 1, or a calm
    /// placeholder while the engine spins up.
    var activeDecisionRuling: String {
        scenario1BriefViewModel?.decision.ruling
            ?? "Preparing decision support…"
    }

    /// Last time the user edited Scenario 1's inputs. Absolute
    /// timestamp — never a relative phrase.
    var activeDecisionLastUpdatedAt: Date? {
        scenario1BriefViewModel?.record.updatedAt
    }

    /// How many user-side checks Scenario 1 still wants cleared.
    var activeDecisionOutstandingCheckCount: Int {
        scenario1BriefViewModel?.decision.outstandingChecks.count ?? 0
    }

    /// Whether the user has supplied any meaningful input to
    /// Scenario 1 yet. Drives the history section's empty-state.
    var hasInteractedWithActiveDecision: Bool {
        guard let state = scenario1BriefViewModel?.state else { return false }
        return state.cartShippingReviewed
            || state.airbnbPackageReceiptConfirmed
            || state.chaseAvailableCreditUSD != nil
            || state.chaseCurrentBalanceUSD != nil
            || state.chaseWillPayBeforeStatementClose
            || state.wiseUSDBalanceUSD != nil
            || state.wiseCardAcceptedByAmazon
            || state.hasLinkedChaseAccount
    }

    // MARK: - Private summary builders

    private func scenario1Summary() -> DecisionSummary {
        DecisionSummary(
            ruling: activeDecisionRuling,
            lastUpdatedAt: activeDecisionLastUpdatedAt,
            outstandingCheckCount: activeDecisionOutstandingCheckCount
        )
    }

    private func creditTimingSummary(
        accounts: [Account],
        now: Date
    ) -> DecisionSummary {
        let decision = CreditTimingDecisionEngine.decide(
            accounts: accounts,
            now: now
        )
        let lastUpdatedAt = accounts
            .filter(\.isCreditCard)
            .compactMap(\.financialSnapshotUpdatedAt)
            .max()
        return DecisionSummary(
            ruling: decision.ruling.displaySummary,
            lastUpdatedAt: lastUpdatedAt,
            outstandingCheckCount: decision.outstandingCheckCount
        )
    }

    private func purchaseDecisionSummary(
        accounts: [Account],
        now: Date
    ) -> DecisionSummary {
        guard let briefViewModel = purchaseDecisionBriefViewModel else {
            return DecisionSummary(
                ruling: "Tap to start a purchase card check.",
                lastUpdatedAt: nil,
                outstandingCheckCount: 0
            )
        }
        let decision = briefViewModel.decision(accounts: accounts, now: now)
        return DecisionSummary(
            ruling: decision.ruling.displaySummary,
            lastUpdatedAt: briefViewModel.record.updatedAt,
            outstandingCheckCount: decision.outstandingCheckCount
        )
    }
}
