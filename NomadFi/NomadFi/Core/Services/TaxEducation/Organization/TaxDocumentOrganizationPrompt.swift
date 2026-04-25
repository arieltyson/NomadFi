// TaxDocumentOrganizationPrompt.swift
// NomadFi
//
// Pure value type for a single Tax Vault organization prompt.
// Built on demand by `TaxDocumentOrganizationPromptService` from
// the user's active jurisdictions, what's already on file in the
// archive, and (where it backs the prompt) the official regulator
// page. Nothing is persisted — these are derived views over
// existing records.
//
// Copy contract:
//   • Procedural language only.
//   • No filing, deduction, or compliance claim.
//   • No fake completeness statement.
//   • Source-backed prompts cite at least one regulator URL.

import Foundation

/// A calm, deterministic Tax Vault Learn prompt the user can act
/// on or read. Reuses `TaxEducationSource` for citations so the
/// prompt card and the lesson detail sheet share one shape.
struct TaxDocumentOrganizationPrompt: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier. Built from `region.rawValue` + `kind`
    /// so two regions can host the same prompt kind without
    /// colliding inside a `ForEach`.
    let id: String

    let region: TaxEducationRegion

    let kind: TaxDocumentOrganizationPromptKind

    let title: String

    /// Two-to-four-sentence body. Procedural framing — explains
    /// what this prompt is and why it's worth a moment, never what
    /// the user "should" do.
    let body: String

    /// Where the primary action button routes the user. `.none`
    /// means there is no primary action — the card stays
    /// informational and only renders the source link.
    let actionTarget: TaxDocumentOrganizationPromptTarget

    /// Label rendered on the primary action button. `nil` when
    /// `actionTarget == .none`.
    let actionTitle: String?

    /// Official-source citations. Empty for the action prompts
    /// (`scanFirstDocument` / `verifyArchive`) since their guidance
    /// is purely procedural about NomadFi's own surfaces. The
    /// `recordkeepingPrinciples` kind always carries at least one
    /// regulator citation, enforced by the service tests.
    let sources: [TaxEducationSource]
}
