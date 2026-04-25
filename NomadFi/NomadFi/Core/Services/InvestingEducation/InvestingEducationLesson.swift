// InvestingEducationLesson.swift
// NomadFi
//
// Pure value type for a single investing-education lesson. Mirrors
// the field shape of `TaxEducationLesson` so the surface views stay
// uniform — but the catalogue never claims one is right for the
// reader. NomadFi's investing surface is education and planning
// context only; nothing here is investment advice, suitability
// guidance, or a recommendation to buy or sell.

import Foundation

struct InvestingEducationLesson: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — `region.rawValue` prefixed so two
    /// regions can share a lesson slug without collision.
    let id: String

    let region: InvestingEducationRegion

    let title: String

    /// Short explanation (1–3 sentences). Concept-focused.
    let whatItIs: String

    /// Why reviewing this matters for an informed reader. Never
    /// promises an outcome.
    let whyItMatters: String

    /// Concrete next-step review prompts — procedural, source-
    /// pointing language only.
    let whatToReviewNext: [String]

    /// Official-source citations. Lessons with an empty `sources`
    /// array are rejected by `InvestingEducationCatalog` validation.
    let sources: [InvestingEducationSource]

    /// Optional escalation reminder surfaced on the detail view
    /// when the lesson's subject would benefit from a registered
    /// professional (e.g. asset allocation across borders).
    let escalationNote: String?
}
