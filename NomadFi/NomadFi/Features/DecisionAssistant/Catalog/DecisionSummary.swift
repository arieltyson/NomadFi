// DecisionSummary.swift
// NomadFi
//
// Pure value type the Decision Assistant hero rows render. Keeps the
// view free of engine-specific conditionals: each active decision
// renders the same ruling line, same "as of" timestamp, and same
// outstanding-check chip regardless of which engine produced it.

import Foundation

/// One-line summary of an active decision. Built by the view model
/// from whichever engine backs the decision — Scenario 1's brief
/// view model, the Credit Timing engine, and any future deterministic
/// engine will all project into this shape.
struct DecisionSummary: Sendable, Equatable {

    /// The engine's top-line ruling, ready for display on the hero.
    let ruling: String

    /// Last time the underlying data changed, when the engine tracks
    /// one. `nil` when the ruling is fully derivable from saved
    /// catalog data (e.g. a fresh app install).
    let lastUpdatedAt: Date?

    /// How many user-side checks the engine still wants cleared.
    let outstandingCheckCount: Int
}
