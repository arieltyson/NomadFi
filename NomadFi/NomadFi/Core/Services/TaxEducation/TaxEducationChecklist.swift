// TaxEducationChecklist.swift
// NomadFi
//
// Region checklist surfaced on the Tax Vault education section.
// Procedural prompts only — never filing instructions or a
// professional-advice claim.

import Foundation

struct TaxEducationChecklist: Sendable, Equatable, Identifiable, Hashable {
    /// Stable identifier — region raw value is enough since there's
    /// at most one starter checklist per region.
    var id: String { region.rawValue }

    let region: TaxEducationRegion

    let title: String

    /// Short, scannable items. The UI renders every item in order.
    let items: [TaxEducationChecklistItem]

    /// Escalation note surfaced as the card's footer.
    let escalationNote: String
}
