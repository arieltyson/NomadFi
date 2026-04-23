// TaxEducationChecklistItem.swift
// NomadFi
//
// One row on a region checklist card. Pure value type — the
// checklist surface is read-only in this slice (no progress
// persistence, no streaks, no badges).

import Foundation

struct TaxEducationChecklistItem: Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let text: String
}
