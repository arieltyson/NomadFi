// TaxEducationProgressRecord.swift
// NomadFi
//
// Persisted progress marker for the Phase 7B+7C education
// scaffolding. One record per (region, kind, identifier) tuple:
//
//   • (.lesson, regionRawValue, lessonID, "", "")
//   • (.checklistItem, regionRawValue, "", checklistItemID, "")
//   • (.quiz, regionRawValue, "", "", quizID)
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

    /// `TaxEducationProgressKind.rawValue` — `"lesson"` /
    /// `"checklistItem"` / `"quiz"`.
    var kindRawValue: String = TaxEducationProgressKind.lesson.rawValue

    /// Lesson identifier when `kind == .lesson`, empty otherwise.
    var lessonID: String = ""

    /// Checklist-item identifier when `kind == .checklistItem`,
    /// empty otherwise.
    var checklistItemID: String = ""

    /// Quiz identifier when `kind == .quiz`, empty otherwise.
    /// Added in Phase 7C; existing lesson / checklist records
    /// migrate forward with the default empty string.
    var quizID: String = ""

    /// Latest quiz attempt's score (0–100). `nil` for lesson /
    /// checklist records and for quiz records that have never been
    /// attempted. CloudKit-safe: optional, no default inference.
    var quizScorePercent: Double? = nil

    /// Latest attempt's correct-answer count.
    var quizCorrectCount: Int? = nil

    /// Number of questions at the latest attempt. Tracked so UI
    /// can render "X of Y correct" honestly even if the quiz
    /// catalogue's length changes later.
    var quizQuestionCount: Int? = nil

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
        quizID: String = "",
        quizScorePercent: Double? = nil,
        quizCorrectCount: Int? = nil,
        quizQuestionCount: Int? = nil,
        statusRawValue: String = TaxEducationProgressStatus.notStarted.rawValue,
        lastInteractedAt: Date? = nil
    ) {
        self.regionRawValue = regionRawValue
        self.kindRawValue = kindRawValue
        self.lessonID = lessonID
        self.checklistItemID = checklistItemID
        self.quizID = quizID
        self.quizScorePercent = quizScorePercent
        self.quizCorrectCount = quizCorrectCount
        self.quizQuestionCount = quizQuestionCount
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
