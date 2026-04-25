// DecisionIdentity.swift
// NomadFi
//
// Pure, Sendable descriptor for a decision the assistant can reason
// about. Kept separate from the persistence layer (`ScenarioDecision-
// Record`) and from the deterministic engine (`ScenarioDecisionEngine`)
// so the UI can iterate, sort, and filter decisions without touching
// SwiftUI or SwiftData types.

import Foundation

/// Stable identifier for a known decision flow. New decisions extend
/// this enum; the raw value is the persistence key already used by
/// `ScenarioDecisionRecord` when one exists.
enum DecisionID: String, Codable, Hashable, Sendable, CaseIterable {

    /// Amazon.com arrival order — Scenario 1 in the docs. Backed by
    /// ``ScenarioDecisionEngine`` and `ScenarioDecisionRecord.scenario1ID`.
    case amazonArrivalOrder

    /// Portfolio-wide credit-timing readiness. Backed by
    /// ``CreditTimingDecisionEngine`` and sourced from the user's
    /// saved `Account` rows rather than a dedicated persistence record.
    case creditTimingCheck

    /// Generic purchase ranking — "Which card or method should I
    /// use for this merchant / category / amount?" Backed by
    /// ``PurchaseDecisionEngine`` and persisted via
    /// ``PurchaseDecisionRecord``.
    case purchaseCardCheck
}

/// Display-level metadata that the Decision Assistant lists use to
/// present a decision before its full brief has been fetched.
///
/// Source of truth is the catalog (see ``DecisionCatalog``) — never
/// free-text at the call site. This keeps copy, tint, and symbol
/// consistent across the active-decision hero, the history row, and
/// any future decision summary.
struct DecisionIdentity: Sendable, Identifiable, Hashable {

    let id: DecisionID
    let title: String
    let summary: String
    let systemImage: String
    let locationContext: String
    let currencyContext: String
}

// MARK: - Availability

extension DecisionIdentity {

    /// Whether NomadFi currently has a deterministic engine behind
    /// this decision. The Decision Assistant surfaces only available
    /// decisions as actionable; anything else belongs in the
    /// `NewDecisionScaffoldCard` as "coming soon".
    var hasDeterministicEngine: Bool {
        switch id {
        case .amazonArrivalOrder: true
        case .creditTimingCheck: true
        case .purchaseCardCheck: true
        }
    }
}

// MARK: - Surface category (Decisions IA)

/// How a decision should surface on the Decisions tab. The IA
/// redesign separates evergreen tools the user can invoke any time
/// from scenario-specific decisions tied to a particular real-world
/// situation, so the screen reads honestly at first glance.
enum DecisionSurfaceCategory: Sendable, Equatable, Hashable {

    /// Reusable check — an evergreen tool the user can invoke any
    /// time (Purchase Card Check, Credit Timing Check). Rendered
    /// in the `Reusable checks` section as a compact action card.
    case reusableCheck

    /// Pinned scenario — a decision tied to a specific real-world
    /// situation, kept visible because it is ongoing rather than
    /// invocable on demand (Amazon arrival order today). Rendered
    /// in the `Pinned scenario` section with its own visual
    /// treatment so it never reads as a reusable tool.
    case pinnedScenario
}

extension DecisionIdentity {

    /// How this identity should surface on the Decisions tab.
    /// Decided per-`DecisionID` so the catalog stays the single
    /// source of truth and the view never branches on string
    /// matches.
    var surfaceCategory: DecisionSurfaceCategory {
        switch id {
        case .amazonArrivalOrder: .pinnedScenario
        case .creditTimingCheck, .purchaseCardCheck: .reusableCheck
        }
    }
}
