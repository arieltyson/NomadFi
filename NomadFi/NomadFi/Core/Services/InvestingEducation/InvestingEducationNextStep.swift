// InvestingEducationNextStep.swift
// NomadFi
//
// Deterministic "what to review next" pointer for a single region.
// Pure value type — the service rebuilds it on demand from the
// catalogue + persisted records. Same shape the tax stack uses so
// the row component stays uniform across the two surfaces.

import Foundation

struct InvestingEducationNextStep: Sendable, Equatable, Identifiable {

    enum Kind: String, Sendable, Equatable, Hashable {
        case checklistItem
        case lesson
    }

    let id: String
    let region: InvestingEducationRegion
    let kind: Kind
    let title: String
    let subtitle: String
    let lessonID: String?
    let checklistItemID: String?

    init(
        id: String,
        region: InvestingEducationRegion,
        kind: Kind,
        title: String,
        subtitle: String,
        lessonID: String? = nil,
        checklistItemID: String? = nil
    ) {
        self.id = id
        self.region = region
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.lessonID = lessonID
        self.checklistItemID = checklistItemID
    }
}
