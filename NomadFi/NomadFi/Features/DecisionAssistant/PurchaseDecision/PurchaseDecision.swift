// PurchaseDecision.swift
// NomadFi
//
// Top-level output of the generic purchase engine. Pure value type
// so it passes cleanly to tests, dialog formatters, and any future
// App Intent surface.

import Foundation

/// The generic purchase engine's full output.
struct PurchaseDecision: Sendable, Equatable {

    /// Context that produced this decision — echoed back so the UI
    /// never needs to re-read the persistence layer to render the
    /// brief.
    let context: PurchaseContext

    /// Portfolio-level ruling.
    let ruling: PurchaseDecisionRuling

    /// The primary recommended assessment, when one clears every
    /// guardrail. `nil` for every non-`ready` ruling.
    let recommendation: PurchaseCandidateAssessment?

    /// Second-best candidate, if there is one. Always distinct from
    /// ``recommendation``.
    let fallback: PurchaseCandidateAssessment?

    /// Every evaluated candidate — usable and blocked — in engine
    /// severity order. Includes the recommendation + fallback.
    let candidates: [PurchaseCandidateAssessment]

    /// "When not to use" warnings attached to the primary
    /// recommendation (and the fallback when relevant). Pre-joined
    /// by the engine so the UI just renders the list.
    let whenNotToUseWarnings: [String]

    /// De-duplicated missing-data / verification checklist across
    /// every candidate.
    let missingDataChecklist: [String]

    /// Hard rules pinned on every brief.
    let hardRules: [String]

    /// Cited sources the UI lists under Sources.
    let citations: [ScenarioCitation]

    /// `now` the engine used. Tests pin this; the UI surfaces an
    /// absolute "evaluated as of" timestamp.
    let evaluatedAt: Date

    /// Phase 3 follow-through — deterministic travel / cross-border
    /// signals derived from the typed context and the candidate
    /// account currencies. Used by the brief and the dialog layer
    /// to surface DCC / FX-verification / dispute caveats only when
    /// the context warrants them. Never a geolocation result.
    let travelContext: PurchaseTravelContext

    /// Phase 3 follow-through — explicit, deterministic confidence
    /// label for the recommendation. Procedural; never marketing.
    /// `.lowOrUnverified` when the engine cannot stand behind the
    /// recommendation (FX unverified or no recommendation at all).
    let confidence: PurchaseDecisionConfidence

    /// Short, factual reasons that drove the confidence label.
    /// Rendered in the brief's confidence section and read out by
    /// the voice dialog when relevant.
    let confidenceExplanations: [String]
}

// MARK: - Derived

extension PurchaseDecision {

    /// Count of outstanding user-side checks — feeds the hero's
    /// "N checks remaining" chip.
    var outstandingCheckCount: Int {
        missingDataChecklist.count
    }

    /// Number of candidates the engine evaluated across all stances.
    var candidateCount: Int {
        candidates.count
    }
}
