// DecisionAssistantViewModel.swift
// NomadFi
//
// Owns the Decision Assistant's persistent state: the catalog-backed
// active decision, the brief view-model it opens, and a few derived
// values used by the view (last-updated timestamps, empty-state
// flags). View logic stays here — the view stays a thin render.

import Foundation
import Observation
import OSLog
import SwiftData

/// Drives the Decision Assistant tab.
@MainActor
@Observable
final class DecisionAssistantViewModel {

    // MARK: - State

    /// The currently-promoted active decision. Derived from the
    /// catalog so adding a decision later doesn't require touching
    /// the view model.
    let activeDecision: DecisionIdentity?

    /// Decisions that can appear in the history / previous list,
    /// regardless of whether they have a persisted record yet.
    let historicalDecisions: [DecisionIdentity]

    /// Brief view-model behind the active decision. Lazily materialised
    /// once the owning view hands the view model a `ModelContext` via
    /// ``bootstrap(modelContext:)``.
    private(set) var scenario1BriefViewModel: ScenarioDecisionBriefViewModel?

    /// True when the brief sheet is presented. Owned by the view
    /// model so Siri / App Intent deep links can flip it programmatically.
    var isBriefPresented: Bool = false

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
        historicalDecisions: [DecisionIdentity] = DecisionCatalog.historicalCandidates
    ) {
        self.activeDecision = activeDecision
        self.historicalDecisions = historicalDecisions
    }

    // MARK: - Bootstrap

    /// Fetches or creates the Scenario 1 record and wraps it in a
    /// brief view-model. Safe to call more than once — subsequent
    /// calls are no-ops so the record stays stable across view
    /// rebuilds.
    func bootstrap(modelContext: ModelContext) {
        guard scenario1BriefViewModel == nil else { return }
        let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(
            in: modelContext
        )
        scenario1BriefViewModel = ScenarioDecisionBriefViewModel(record: record)
    }

    // MARK: - Intents

    /// Opens the brief for the active decision. Currently only
    /// Scenario 1 is wired; guards so Siri / intent-driven callers
    /// can't accidentally present an empty sheet.
    func openActiveDecision() {
        guard scenario1BriefViewModel != nil else {
            Self.logger.warning("openActiveDecision called before bootstrap completed")
            return
        }
        isBriefPresented = true
    }

    /// Opens a specific decision by identifier. Used by the history
    /// list and reserved for future App Intent deep links
    /// (`DecisionID` is already `Codable`).
    func openDecision(_ id: DecisionID) {
        switch id {
        case .amazonArrivalOrder:
            openActiveDecision()
        }
    }

    /// Presents the decision-draft capture sheet. Tapped from the
    /// "Capture decision" button on ``NewDecisionScaffoldCard``.
    func presentDraftForm() {
        isDraftFormPresented = true
    }

    // MARK: - Derived

    /// Human-readable ruling string for the active decision, or a
    /// calm placeholder while the engine spins up.
    var activeDecisionRuling: String {
        scenario1BriefViewModel?.decision.ruling
            ?? "Preparing decision support…"
    }

    /// Last time the user edited the active decision's inputs.
    /// Surfaces as an absolute "as of" timestamp in the UI — never a
    /// relative phrase.
    var activeDecisionLastUpdatedAt: Date? {
        scenario1BriefViewModel?.record.updatedAt
    }

    /// How many user-side checks the engine still wants the user to
    /// clear. Drives the hero's "\(count) checks remaining" chip.
    var activeDecisionOutstandingCheckCount: Int {
        scenario1BriefViewModel?.decision.outstandingChecks.count ?? 0
    }

    /// Whether the user has supplied any meaningful input to the
    /// active decision yet. Drives the history section's choice
    /// between showing a real row or an empty-state pointer.
    ///
    /// We intentionally inspect the record's derived state instead
    /// of comparing timestamps: `ScenarioDecisionRecord.updatedAt`
    /// defaults to `.now` on creation, so a timestamp check would
    /// report every freshly-created record as "interacted".
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
}
