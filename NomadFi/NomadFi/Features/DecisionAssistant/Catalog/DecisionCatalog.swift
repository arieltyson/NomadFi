// DecisionCatalog.swift
// NomadFi
//
// The static list of decisions NomadFi knows how to reason about.
// The Decision Assistant reads from this catalog rather than
// hardcoding Amazon-specific copy into the UI, so adding a second
// decision later is a data-only change.

import Foundation

/// Read-only catalog of decisions surfaced in the Decision Assistant.
///
/// Three deterministic engines ship today: the Amazon arrival
/// scenario (`ScenarioDecisionEngine`), the portfolio-wide credit-
/// timing check (`CreditTimingDecisionEngine`), and the generic
/// purchase-card check (`PurchaseDecisionEngine` — which covers
/// cross-border / travel context as of Phase 3 follow-through).
/// The structure leaves room for more decisions without bending
/// the UI later.
enum DecisionCatalog {

    /// All decisions known to the app, in display order. The first
    /// entry is currently promoted to the "Active Decision" hero on
    /// the Decision Assistant surface; additional entries render as
    /// sibling heroes beneath it.
    static let all: [DecisionIdentity] = [
        amazonArrivalOrder,
        creditTimingCheck,
        purchaseCardCheck,
    ]

    /// Amazon.com arrival order — Scenario 1. Cross-border purchase
    /// from Canada into a U.S. summer address, backed by
    /// ``ScenarioDecisionEngine``.
    static let amazonArrivalOrder = DecisionIdentity(
        id: .amazonArrivalOrder,
        title: "Amazon arrival order",
        summary: "Cross-border U.S. delivery — pay in USD or CAD?",
        systemImage: "cart.fill.badge.plus",
        locationContext: "U.S. summer address",
        currencyContext: "USD vs. CAD"
    )

    /// Portfolio-wide credit-timing check. Backed by
    /// ``CreditTimingDecisionEngine`` — reads the user's saved credit
    /// cards, their schedules, and their latest snapshots to surface
    /// paydown-before-close and near-limit guidance. Strictly a
    /// timing / utilization engine; never a credit-score predictor.
    static let creditTimingCheck = DecisionIdentity(
        id: .creditTimingCheck,
        title: "Credit timing check",
        summary: "Statement close and utilization readiness",
        systemImage: "calendar.badge.clock",
        locationContext: "Your saved credit cards",
        currencyContext: "Per-card currency"
    )

    /// Generic purchase ranking. Backed by
    /// ``PurchaseDecisionEngine`` — ranks the user's non-investment
    /// accounts for a typed merchant / category / amount, with
    /// hard-rule guardrails around debt, stale snapshots, and
    /// unverified FX fees.
    static let purchaseCardCheck = DecisionIdentity(
        id: .purchaseCardCheck,
        title: "Purchase card check",
        summary: "Which card or method for this purchase?",
        systemImage: "creditcard.and.123",
        locationContext: "Any merchant or category",
        currencyContext: "Cross-currency aware"
    )

    /// Fetches a decision by its stable identifier. Returns nil for
    /// unknown IDs — callers should treat this as a hard boundary
    /// error (a decision referenced by persistence but absent from
    /// the catalog) and log it at the feature layer.
    static func decision(for id: DecisionID) -> DecisionIdentity? {
        all.first { $0.id == id }
    }

    /// Currently-actionable decision for the Decision Assistant
    /// hero. Derived from ``all`` so the UI pattern scales with the
    /// catalog instead of hard-coding Amazon everywhere.
    static var activeDecision: DecisionIdentity? {
        all.first { $0.hasDeterministicEngine }
    }

    /// Decisions *eligible* to appear in the "Previous decisions"
    /// list — i.e. every catalog identity that ships a deterministic
    /// engine. Membership in this set is **not** the same as
    /// "actually reviewed". The view-model filters this candidate
    /// list through `DecisionReviewEvidence.reviewedDecisionIDs(...)`
    /// at render time so untouched decisions never appear under
    /// "Previous decisions".
    static var historicalCandidates: [DecisionIdentity] {
        all.filter(\.hasDeterministicEngine)
    }

    /// Reusable checks the user can invoke any time — evergreen
    /// tools that don't belong to a specific scenario. Surfaced in
    /// the Decision Assistant's `Reusable checks` section. The order
    /// here is the catalog order (purchase, then credit timing).
    static var reusableChecks: [DecisionIdentity] {
        all.filter { $0.surfaceCategory == .reusableCheck }
    }

    /// Scenario-specific decisions that stay pinned to the user's
    /// surface because they are tied to a particular real-world
    /// situation (rather than a tool the user invokes in general).
    /// Surfaced in the Decision Assistant's `Pinned scenario` section.
    static var pinnedScenarios: [DecisionIdentity] {
        all.filter { $0.surfaceCategory == .pinnedScenario }
    }
}
