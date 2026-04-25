// InvestingEducationProgressKind.swift
// NomadFi
//
// Discriminator for `InvestingEducationProgressRecord`. One record
// per (region, kind, identifier) tuple — same shape the tax
// education stack uses, kept separate so the two progressions never
// share rows. Phase 8A ships only `lesson` + `checklistItem`; a
// future quiz / recognition layer would add cases here without
// touching the existing schema.

import Foundation

enum InvestingEducationProgressKind: String, Sendable, Equatable, Hashable, CaseIterable {
    case lesson
    case checklistItem
}
