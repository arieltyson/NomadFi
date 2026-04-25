// InvestingEducationProgressRecord.swift
// NomadFi
//
// Persisted progress marker for the Phase 8A investing-education
// scaffolding. One record per (region, kind, identifier) tuple:
//
//   • (.lesson, regionRawValue, lessonID, "")
//   • (.checklistItem, regionRawValue, "", checklistItemID)
//
// Kept as a sibling model to `TaxEducationProgressRecord` rather
// than a shared abstraction so the two progressions can evolve
// independently — investing may grow a quiz / fund-watchlist field
// later that tax doesn't need, and vice versa.
//
// CloudKit-safe per the repo's standing rules:
//   • all fields optional / defaulted,
//   • no `@Attribute(.unique)`,
//   • no inverse relationships (progress out-lives transient
//     jurisdiction edits — if a user removes Canada and re-adds it,
//     CIRO checklist progress reappears rather than vanishing
//     silently).

import Foundation
import SwiftData

@Model
final class InvestingEducationProgressRecord {

    /// `InvestingEducationRegion.rawValue`. Stored as a String so
    /// the model stays stable if the enum gains cases.
    var regionRawValue: String = ""

    /// `InvestingEducationProgressKind.rawValue` —
    /// `"lesson"` / `"checklistItem"`.
    var kindRawValue: String = InvestingEducationProgressKind.lesson.rawValue

    /// Lesson identifier when `kind == .lesson`, empty otherwise.
    var lessonID: String = ""

    /// Checklist-item identifier when `kind == .checklistItem`,
    /// empty otherwise.
    var checklistItemID: String = ""

    /// `InvestingEducationProgressStatus.rawValue`. Defaults to
    /// `"notStarted"` so a freshly-inserted record is a no-op
    /// until something actually flips it.
    var statusRawValue: String = InvestingEducationProgressStatus.notStarted.rawValue

    /// Timestamp of the last user interaction. `nil` until the
    /// record is first written.
    var lastInteractedAt: Date? = nil

    init(
        regionRawValue: String = "",
        kindRawValue: String = InvestingEducationProgressKind.lesson.rawValue,
        lessonID: String = "",
        checklistItemID: String = "",
        statusRawValue: String = InvestingEducationProgressStatus.notStarted.rawValue,
        lastInteractedAt: Date? = nil
    ) {
        self.regionRawValue = regionRawValue
        self.kindRawValue = kindRawValue
        self.lessonID = lessonID
        self.checklistItemID = checklistItemID
        self.statusRawValue = statusRawValue
        self.lastInteractedAt = lastInteractedAt
    }

    // MARK: - Typed projections

    var region: InvestingEducationRegion? {
        InvestingEducationRegion(rawValue: regionRawValue)
    }

    var kind: InvestingEducationProgressKind {
        InvestingEducationProgressKind(rawValue: kindRawValue) ?? .lesson
    }

    var status: InvestingEducationProgressStatus {
        InvestingEducationProgressStatus.from(rawValue: statusRawValue)
    }
}
