// DecisionReviewEvidence.swift
// NomadFi
//
// Pure derivation namespace that decides which catalog decisions
// have actually been reviewed by the user. Drives the rendered
// "Previous decisions" list — and therefore the empty-state path —
// on the Decision Assistant surface.
//
// Honesty contract pinned in `DecisionReviewEvidenceTests`:
//
//   • A fresh user with no scenario inputs, no purchase amount, and
//     no review markers has zero reviewed decisions. The empty-
//     state path on `DecisionAssistantView` becomes reachable.
//   • Scenario 1 counts as reviewed only when the user has supplied
//     real input through the brief (`scenarioInteracted`).
//   • Purchase Card Check counts as reviewed only when the user has
//     typed a positive amount (`purchaseHasUsableContext` — the
//     existing `PurchaseDecisionRecord.hasUsableContext` rule).
//   • Credit Timing counts as reviewed only when the user has
//     explicitly opened the brief at least once
//     (`creditTimingMarkerStamped`). Having a credit card on file
//     is *not* enough — the card existed before the engine did.
//   • The function is pure over its inputs — same inputs always
//     yield the same set.

import Foundation

/// Pure namespace that maps current evidence into the set of
/// `DecisionID` values that count as "previously reviewed".
enum DecisionReviewEvidence {

    /// Returns the deterministic set of reviewed decisions.
    ///
    /// - Parameters:
    ///   - scenarioInteracted: Mirrors
    ///     `DecisionAssistantViewModel.hasInteractedWithActiveDecision` —
    ///     `true` once the Scenario 1 record has any user-supplied
    ///     input.
    ///   - purchaseHasUsableContext: Mirrors
    ///     `PurchaseDecisionRecord.hasUsableContext` — `true` once a
    ///     positive amount is typed into the Purchase brief.
    ///   - creditTimingMarkerStamped: `true` once the
    ///     `DecisionReviewMarker` for `.creditTimingCheck` has a
    ///     non-nil `lastReviewedAt`. This is the only honest signal
    ///     for Credit Timing because that engine has no per-engine
    ///     input record to anchor on.
    static func reviewedDecisionIDs(
        scenarioInteracted: Bool,
        purchaseHasUsableContext: Bool,
        creditTimingMarkerStamped: Bool
    ) -> Set<DecisionID> {
        var reviewed: Set<DecisionID> = []
        if scenarioInteracted {
            reviewed.insert(.amazonArrivalOrder)
        }
        if purchaseHasUsableContext {
            reviewed.insert(.purchaseCardCheck)
        }
        if creditTimingMarkerStamped {
            reviewed.insert(.creditTimingCheck)
        }
        return reviewed
    }

    /// Convenience for callers that have a `[DecisionReviewMarker]`
    /// query result rather than a single boolean. Returns `true`
    /// when the array contains a row for `id` whose
    /// `lastReviewedAt` is non-nil.
    static func markerStamped(
        for id: DecisionID,
        in markers: [DecisionReviewMarker]
    ) -> Bool {
        markers.contains {
            $0.decisionIDRawValue == id.rawValue
                && $0.lastReviewedAt != nil
        }
    }
}
