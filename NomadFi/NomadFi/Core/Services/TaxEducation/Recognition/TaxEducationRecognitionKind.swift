// TaxEducationRecognitionKind.swift
// NomadFi
//
// Calm, derived recognition kinds for the Tax Vault Learn surface.
// Recognition is *current-state* only — the computer re-derives the
// list from the persisted `TaxEducationProgressRecord`s on every
// read, so regressing progress removes the corresponding badge.
// No points, no XP, no lifetime trophies.

import Foundation

/// Kinds of recognition the Learn surface can show. Adding a new
/// kind is a two-file edit: add a case here, extend the computer.
/// Keep the set small — HIG-aligned restraint matters more than
/// coverage.
enum TaxEducationRecognitionKind: Sendable, Equatable, Hashable {

    /// The user has completed *any* explicit step (lesson,
    /// checklist item, or quiz attempt) across any region. The
    /// lightest recognition — appears as soon as the user engages.
    case firstStepReviewed

    /// The user has completed every lesson and every checklist
    /// item for the named region. Quiz is not required here —
    /// `starterReviewed` is the pre-quiz milestone.
    case starterReviewed(TaxEducationRegion)

    /// The user has passed the knowledge-check quiz for the
    /// named region.
    case knowledgeCheckPassed(TaxEducationRegion)

    /// The user has completed every lesson, checklist item, and
    /// (when present) passed the quiz for the named region.
    /// Equivalent to `TaxEducationRegionProgressSummary.isReviewed`.
    case regionReviewed(TaxEducationRegion)

    /// The user has fully reviewed two or more regions. Recognises
    /// cross-border breadth — the core NomadFi use case — without
    /// turning it into a score.
    case multiRegionReviewed
}
