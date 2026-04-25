// InvestingEducationChecklistItem.swift
// NomadFi
//
// Pure value type for a single checklist item inside a region's
// investing-education starter. Mirrors `TaxEducationChecklistItem`
// so the UI rendering stays consistent across the two surfaces.

import Foundation

struct InvestingEducationChecklistItem: Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let text: String
}
