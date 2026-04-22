// CreditTimingCardAssessment.swift
// NomadFi
//
// Pure per-card output of the Credit Timing engine. Renders as a row
// in the brief sheet. Carries every derived value the UI needs so the
// view never has to reach back into the `Account` model — keeps the
// UI layer from re-implementing utilization math, and keeps tests off
// SwiftData for the engine proper.

import Foundation

/// Deterministic assessment of a single credit card.
///
/// Immutable value type; equality is by `id`. The `id` uses the
/// account's stable identity so re-running the engine on the same
/// account produces the same row identifier.
struct CreditTimingCardAssessment: Identifiable, Sendable, Equatable {

    /// Stable identifier. Derived from the account's name and
    /// institution rather than `PersistentIdentifier` so the value
    /// stays `Sendable` and test-friendly.
    let id: String

    /// User-facing display name of the card.
    let accountName: String

    /// Issuer name shown as a secondary line.
    let institutionName: String

    /// Currency code used to format amounts.
    let currencyCode: String

    /// The ruling the engine assigned.
    let ruling: CreditTimingCardRuling

    /// `currentBalance / creditLimit` when both are known and the
    /// limit is positive. `nil` means the engine had no honest answer.
    let utilization: Double?

    /// Band the utilization falls into, when computable.
    let utilizationBand: CreditTimingUtilizationBand?

    /// Raw user-entered current balance, carried through for display.
    let currentBalance: Double?

    /// Raw user-entered credit limit.
    let creditLimit: Double?

    /// Statement closing date from the card's schedule. `nil` when the
    /// schedule is not confirmed.
    let statementClosingDate: Date?

    /// Payment due date from the card's schedule.
    let paymentDueDate: Date?

    /// Last time the user refreshed the financial snapshot.
    let snapshotUpdatedAt: Date?

    /// Whether the snapshot is considered stale by its source's
    /// freshness window.
    let snapshotIsStale: Bool

    /// Coarse schedule state — `.confirmed` is the only state that
    /// unlocks strong rulings.
    let scheduleState: CreditCardScheduleState

    /// Paydown amount to land the reported balance at ≈30% utilization
    /// by statement close. `nil` when already below 30% or the inputs
    /// aren't complete.
    let paydownTargetTo30Percent: Double?

    /// Paydown amount to land at ≈10% utilization. `nil` when already
    /// below 10% or the inputs aren't complete.
    let paydownTargetTo10Percent: Double?

    /// Per-card missing-data / verification items. Aggregated into the
    /// portfolio checklist by the engine.
    let outstandingChecks: [String]
}
