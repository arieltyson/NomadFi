// TaxEducationProgressRecord.swift
// NomadFi
//
// Persisted progress marker for the Phase 7B education scaffolding.
// One record per (region, kind, identifier) tuple:
//
//   • (.lesson, regionRawValue, lessonID, "")
//   • (.checklistItem, regionRawValue, "", checklistItemID)
//
// Uniqueness is enforced in the service layer via a deterministic
// lookup — CloudKit sync does not support `@Attribute(.unique)` in
// a sync-safe way, so every field is optional / defaulted and the
// service resolves collisions by updating the first matching
// record and dropping any duplicates it sees. See
// `TaxEducationProgressService.upsertRecord(...)`.
//
// Not linked to `JurisdictionProfile` via a SwiftData relationship
// on purpose: progress records out-live transient jurisdiction
// edits. If a user removes Canada and later re-adds it, CRA
// checklist progress reappears rather than vanishing silently.

import Foundation
import SwiftData

@Model
final class TaxEducationProgressRecord {

    /// `TaxEducationRegion.rawValue` for the region this record
    /// belongs to. Stored as a String so the model stays stable if
    /// the enum gains cases later.
    var regionRawValue: String = ""

    /// `TaxEducationProgressKind.rawValue` — `"lesson"` or
    /// `"checklistItem"`.
    var kindRawValue: String = TaxEducationProgressKind.lesson.rawValue

    /// Lesson identifier when `kind == .lesson`, empty otherwise.
    var lessonID: String = ""

    /// Checklist-item identifier when `kind == .checklistItem`,
    /// empty otherwise.
    var checklistItemID: String = ""

    /// `TaxEducationProgressStatus.rawValue`. Defaults to
    /// `"notStarted"` so a freshly-inserted record is a no-op
    /// until something actually flips it to `"completed"`.
    var statusRawValue: String = TaxEducationProgressStatus.notStarted.rawValue

    /// Timestamp of the last user interaction. `nil` until the
    /// record is first written.
    var lastInteractedAt: Date? = nil

    init(
        regionRawValue: String = "",
        kindRawValue: String = TaxEducationProgressKind.lesson.rawValue,
        lessonID: String = "",
        checklistItemID: String = "",
        statusRawValue: String = TaxEducationProgressStatus.notStarted.rawValue,
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

    var region: TaxEducationRegion? {
        TaxEducationRegion(rawValue: regionRawValue)
    }

    var kind: TaxEducationProgressKind {
        TaxEducationProgressKind(rawValue: kindRawValue) ?? .lesson
    }

    var status: TaxEducationProgressStatus {
        TaxEducationProgressStatus.from(rawValue: statusRawValue)
    }
}
