// InvestingEducationChecklist.swift
// NomadFi
//
// Per-region procedural checklist. Used by the Investing Learn
// surface to nudge the reader through "what to review next" steps
// before the lesson list. Mirrors `TaxEducationChecklist`.

import Foundation

struct InvestingEducationChecklist: Sendable, Equatable, Identifiable {

    var id: String { region.rawValue }

    let region: InvestingEducationRegion

    let title: String

    let items: [InvestingEducationChecklistItem]

    /// Calm reminder shown under the checklist. Always frames the
    /// content as education, never as advice.
    let escalationNote: String
}
