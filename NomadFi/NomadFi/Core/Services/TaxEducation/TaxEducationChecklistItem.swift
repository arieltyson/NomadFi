// TaxEducationChecklistItem.swift
// NomadFi
//
// One row on a region checklist card. Pure value type — the
// Phase 7B progression layer owns completion state via
// `TaxEducationProgressService`; this value type stays purely
// about catalogue identity.

import Foundation

struct TaxEducationChecklistItem: Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let text: String
}
