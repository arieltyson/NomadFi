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

    /// Catalog set of decisions that are *eligible* to appear in
    /// the "Previous decisions" list. Membership in this set is
    /// not the same as actually-reviewed — see
    /// `reviewedDecisions(reviewMarkers:)` for the rendered list.
    /// Kept under the legacy name `historicalDecisions` so existing
    /// snapshot tests stay readable.
    let historicalDecisions: [DecisionIdentity]

    /// Reusable checks the user can invoke any time. Rendered in
    /// the Decisions tab's `Reusable checks` section after the IA
    /// redesign so evergreen tools stay visually distinct from the
    /// pinned scenario surface.
    let reusableChecks: [DecisionIdentity]

    /// Scenario-specific decisions tied to a particular real-world
    /// situation (Amazon arrival order today). Rendered in the
    /// `Pinned scenario` section.
    let pinnedScenarios: [DecisionIdentity]

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

    /// True when the Phase 9A Apple Intelligence intake sheet is
    /// presented.
    var isAIIntakePresented: Bool = false

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionAssistant"
    )

    init(
        activeDecision: DecisionIdentity? = DecisionCatalog.activeDecision,
        activeDecisions: [DecisionIdentity] = DecisionCatalog.all.filter(\.hasDeterministicEngine),
        historicalDecisions: [DecisionIdentity] = DecisionCatalog.historicalCandidates,
        reusableChecks: [DecisionIdentity] = DecisionCatalog.reusableChecks,
        pinnedScenarios: [DecisionIdentity] = DecisionCatalog.pinnedScenarios
    ) {
        self.activeDecision = activeDecision
        self.activeDecisions = activeDecisions
        self.historicalDecisions = historicalDecisions
        self.reusableChecks = reusableChecks
        self.pinnedScenarios = pinnedScenarios
    }

    // MARK: - Bootstrap

    /// Fetches or creates the deterministic engine records and
    /// wraps them in brief view-models. Safe to call more than once
    /// — each brief bootstraps once and stays stable across view
    /// rebuilds. The `modelContext` is captured by the brief view
    /// models so they can re-resolve their records on every access,
    /// surviving a SwiftData context reset that would otherwise
    /// destroy a held strong reference (see the crash-safety note
    /// in `ScenarioDecisionBriefViewModel`).
    func bootstrap(modelContext: ModelContext) {
        if scenario1BriefViewModel == nil {
            let record = ScenarioDecisionBriefViewModel.fetchOrCreateScenario1Record(
                in: modelContext
            )
            scenario1BriefViewModel = ScenarioDecisionBriefViewModel(
                modelContext: modelContext,
                record: record
            )
        }

        if purchaseDecisionBriefViewModel == nil {
            let record = PurchaseDecisionRecord.fetchOrCreateActiveRecord(
                in: modelContext
            )
            purchaseDecisionBriefViewModel = PurchaseDecisionBriefViewModel(
                modelContext: modelContext,
                record: record
            )
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
    ///
    /// Also stamps the `DecisionReviewMarker` for
    /// `.creditTimingCheck` so the "Previous decisions" section can
    /// honestly distinguish "engine available" from "user has
    /// reviewed it at least once". This is the only honest signal
    /// for Credit Timing — that engine has no per-engine input
    /// record like Scenario 1 or Purchase Card Check.
    ///
    /// `modelContext` is optional so legacy / preview call sites
    /// keep working unchanged. The Decision Assistant view passes
    /// the live `@Environment(\.modelContext)` value.
    func openCreditTimingBrief(
        modelContext: ModelContext? = nil,
        now: Date = .now
    ) {
        if let modelContext {
            DecisionReviewMarker.stamp(
                .creditTimingCheck,
                in: modelContext,
                now: now
            )
        }
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
    /// list and reserved for future App Intent deep links. Passes
    /// the `modelContext` through so Credit Timing can stamp its
    /// review marker at brief-open time.
    func openDecision(
        _ id: DecisionID,
        modelContext: ModelContext? = nil
    ) {
        switch id {
        case .amazonArrivalOrder:
            openActiveDecision()
        case .creditTimingCheck:
            openCreditTimingBrief(modelContext: modelContext)
        case .purchaseCardCheck:
            openPurchaseDecisionBrief()
        }
    }

    /// Presents the decision-draft capture sheet. Tapped from the
    /// "Capture decision" button on ``NewDecisionScaffoldCard``.
    func presentDraftForm() {
        isDraftFormPresented = true
    }

    /// Presents the Phase 9A Apple Intelligence intake sheet.
    /// Tapped from the "Apple Intelligence context" row on
    /// ``NewDecisionScaffoldCard``.
    func presentAIIntake() {
        isAIIntakePresented = true
    }

    // MARK: - Draft → engine handoff (Phase 1 follow-through)

    /// Prefills the singleton ``PurchaseDecisionRecord`` from a
    /// captured draft and opens the existing Purchase Card Check
    /// brief. Pure user-invoked routing — never automatic.
    ///
    /// Honesty contract: this method never marks the draft itself
    /// as "analyzed". The draft's persisted ``DecisionDraftStatus``
    /// stays `.needsEngine` regardless of what the user does in the
    /// brief. The handoff is a one-way *prefill into a separate
    /// engine record*, not a status promotion.
    func openPurchaseDecisionBrief(
        prefillFrom draft: DecisionDraftRecord,
        now: Date = .now
    ) {
        guard let viewModel = purchaseDecisionBriefViewModel else {
            Self.logger.warning(
                "openPurchaseDecisionBrief(prefillFrom:) called before bootstrap completed"
            )
            return
        }
        DraftToPurchaseRecordPrefill.apply(
            draft: draft,
            into: viewModel.record,
            now: now
        )
        viewModel.amountText = PurchaseDecisionBriefViewModel
            .amountEditingText(for: viewModel.record.amount)
        isPurchaseDecisionBriefPresented = true
    }

    // MARK: - Review evidence (Decision Assistant history hardening)

    /// Returns the deterministic "previously reviewed" subset of
    /// the catalog, filtered through `DecisionReviewEvidence`.
    /// The view passes the live `@Query<DecisionReviewMarker>`
    /// results in so the rendered "Previous decisions" list stays
    /// in lockstep with persisted review state.
    func reviewedDecisions(
        reviewMarkers: [DecisionReviewMarker]
    ) -> [DecisionIdentity] {
        let scenarioInteracted = hasInteractedWithActiveDecision
        let purchaseHasUsableContext = purchaseDecisionBriefViewModel?
            .record.hasUsableContext ?? false
        let creditTimingMarkerStamped = DecisionReviewEvidence
            .markerStamped(for: .creditTimingCheck, in: reviewMarkers)

        let reviewedIDs = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: scenarioInteracted,
            purchaseHasUsableContext: purchaseHasUsableContext,
            creditTimingMarkerStamped: creditTimingMarkerStamped
        )
        return historicalDecisions.filter { reviewedIDs.contains($0.id) }
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
