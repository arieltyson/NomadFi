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
/// The catalog is intentionally small today — Scenario 1 (Amazon
/// arrival order) is the single entry with a deterministic engine.
/// The structure leaves room for more decisions without bending the
/// UI later.
enum DecisionCatalog {

    /// All decisions known to the app, in display order. The first
    /// entry is currently promoted to the "Active Decision" hero on
    /// the Decision Assistant surface.
    static let all: [DecisionIdentity] = [amazonArrivalOrder]

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

    /// Decisions eligible for the history list. Any identity with a
    /// deterministic engine becomes a history row once the user has
    /// interacted with its persistence record.
    static var historicalCandidates: [DecisionIdentity] {
        all.filter(\.hasDeterministicEngine)
    }
}
