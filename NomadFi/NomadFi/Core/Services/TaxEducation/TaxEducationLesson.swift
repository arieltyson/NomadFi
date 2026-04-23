// TaxEducationLesson.swift
// NomadFi
//
// Pure value type for a single education lesson. Each field maps
// onto a section of the lesson detail view:
//
//   • `title`                → hero title
//   • `whatItIs`             → "What it is"
//   • `whyItMatters`         → "Why it matters"
//   • `whatToReviewNext`     → "What to review next"
//   • `sources`              → official-source list
//   • `escalationNote`       → optional "Ask a professional" callout
//
// The entire catalogue is locally authored — nothing here is
// generated or scraped. NomadFi provides education and planning
// context only, never filing instructions or professional advice.

import Foundation

struct TaxEducationLesson: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — `region.rawValue` prefixed so two
    /// regions can share a lesson slug without collision.
    let id: String

    let region: TaxEducationRegion

    let title: String

    /// Short explanation (1-3 sentences).
    let whatItIs: String

    /// Why reviewing this matters for a cross-border user.
    let whyItMatters: String

    /// Concrete next-step review prompts — procedural only.
    let whatToReviewNext: [String]

    /// Official-source citations. Lessons with an empty `sources`
    /// array are rejected by `TaxEducationCatalog` validation.
    let sources: [TaxEducationSource]

    /// Optional escalation reminder surfaced on the detail view
    /// when the lesson's subject has judgment-intensive edge cases.
    let escalationNote: String?
}
