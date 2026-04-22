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
        }
    }
}
