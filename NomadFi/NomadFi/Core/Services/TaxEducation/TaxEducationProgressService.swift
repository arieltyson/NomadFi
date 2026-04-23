// TaxEducationProgressService.swift
// NomadFi
//
// Pure read + explicit write service for the Phase 7B / 7C
// education progression. Reads compute summaries and the next
// recommended step deterministically. Writes are the only path
// that can flip a record — there is no implicit transition on
// lesson open or quiz open.
//
// Rules pinned in `TaxEducationProgressServiceTests` and
// `TaxEducationQuizServiceTests`:
//
//   • A lesson with no matching record reads as `.notStarted`.
//   • A checklist item with no matching record reads as
//     `.notStarted`.
//   • A quiz with no matching record reads as `.notStarted`. A
//     failed attempt sets `.inProgress`; a passing attempt sets
//     `.completed`. Retakes overwrite the single record for the
//     quiz id.
//   • `markLessonReviewed(...)` is idempotent — calling it twice
//     on the same lesson produces exactly one record.
//   • `toggleChecklistItem(...)` flips between `.notStarted` and
//     `.completed`; no `.inProgress` state in 7B.
//   • Next-step priority: first uncompleted checklist item in the
//     region's checklist order, then first uncompleted lesson in
//     the region's lesson order, then the knowledge-check quiz
//     (only after every lesson and every checklist item is
//     complete), then `nil` when the region is fully reviewed.
//   • Duplicate persisted records for the same key are tolerated:
//     reads treat the newest `.completed` entry as authoritative,
//     and writes update the first match without removing clones.

import Foundation
import OSLog
import SwiftData

/// Pure read + explicit-write namespace for Phase 7B progression.
enum TaxEducationProgressService {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "TaxEducationProgress"
    )

    // MARK: - Status lookup

    /// Resolves the persisted status for a single lesson.
    /// Pure — safe to call from any actor as long as the caller
    /// has already fetched `records` on the main actor.
    @MainActor
    static func status(
        forLessonID lessonID: String,
        region: TaxEducationRegion,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressStatus {
        let matches = records.filter { record in
            record.kindRawValue == TaxEducationProgressKind.lesson.rawValue
                && record.regionRawValue == region.rawValue
                && record.lessonID == lessonID
        }
        return resolveStatus(from: matches)
    }

    /// Resolves the persisted status for a single checklist item.
    @MainActor
    static func status(
        forChecklistItemID itemID: String,
        region: TaxEducationRegion,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressStatus {
        let matches = records.filter { record in
            record.kindRawValue == TaxEducationProgressKind.checklistItem.rawValue
                && record.regionRawValue == region.rawValue
                && record.checklistItemID == itemID
        }
        return resolveStatus(from: matches)
    }

    /// Resolves the persisted status for a single knowledge-check
    /// quiz. `.notStarted` when no record exists, `.inProgress`
    /// after a failing attempt, `.completed` after a passing
    /// attempt. Retakes always overwrite the latest record.
    @MainActor
    static func status(
        forQuizID quizID: String,
        region: TaxEducationRegion,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressStatus {
        let matches = records.filter { record in
            record.kindRawValue == TaxEducationProgressKind.quiz.rawValue
                && record.regionRawValue == region.rawValue
                && record.quizID == quizID
        }
        return resolveStatus(from: matches)
    }

    /// Returns the most recent persisted record for a quiz, when
    /// one exists. Used by the summary and UI to surface the
    /// latest score alongside the status.
    @MainActor
    static func latestRecord(
        forQuizID quizID: String,
        region: TaxEducationRegion,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressRecord? {
        let matches = records.filter { record in
            record.kindRawValue == TaxEducationProgressKind.quiz.rawValue
                && record.regionRawValue == region.rawValue
                && record.quizID == quizID
        }
        if let completed = matches.first(where: { $0.status == .completed }) {
            return completed
        }
        return matches.max { lhs, rhs in
            (lhs.lastInteractedAt ?? .distantPast)
                < (rhs.lastInteractedAt ?? .distantPast)
        }
    }

    /// Collapses duplicate records for the same key into a single
    /// authoritative status. Any `.completed` beats all other
    /// values; otherwise the newest `lastInteractedAt` wins.
    private static func resolveStatus(
        from matches: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressStatus {
        guard !matches.isEmpty else { return .notStarted }
        if matches.contains(where: { $0.status == .completed }) {
            return .completed
        }
        let newest = matches.max(by: { lhs, rhs in
            (lhs.lastInteractedAt ?? .distantPast)
                < (rhs.lastInteractedAt ?? .distantPast)
        })
        return newest?.status ?? .notStarted
    }

    // MARK: - Per-region summary

    /// Rolls up a region's bundle + records into a
    /// `TaxEducationRegionProgressSummary`.
    @MainActor
    static func summary(
        for bundle: TaxEducationRegionBundle,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationRegionProgressSummary {
        let region = bundle.region

        let lessonsReviewed = bundle.lessons.reduce(into: 0) { running, lesson in
            if status(forLessonID: lesson.id, region: region, in: records) == .completed {
                running += 1
            }
        }

        let checklistCompleted = bundle.checklist.items.reduce(into: 0) { running, item in
            if status(forChecklistItemID: item.id, region: region, in: records) == .completed {
                running += 1
            }
        }

        var quizStatus: TaxEducationProgressStatus = .notStarted
        var quizScorePercent: Double? = nil
        var quizQuestionCount: Int? = nil
        var quizCorrectCount: Int? = nil
        if let quiz = bundle.quiz {
            quizStatus = status(forQuizID: quiz.id, region: region, in: records)
            if let record = latestRecord(forQuizID: quiz.id, region: region, in: records) {
                quizScorePercent = record.quizScorePercent
                quizQuestionCount = record.quizQuestionCount
                quizCorrectCount = record.quizCorrectCount
            }
        }

        return TaxEducationRegionProgressSummary(
            region: region,
            lessonsReviewed: lessonsReviewed,
            lessonsTotal: bundle.lessons.count,
            checklistItemsCompleted: checklistCompleted,
            checklistItemsTotal: bundle.checklist.items.count,
            hasQuiz: bundle.quiz != nil,
            quizStatus: quizStatus,
            quizScorePercent: quizScorePercent,
            quizQuestionCount: quizQuestionCount,
            quizCorrectCount: quizCorrectCount
        )
    }

    // MARK: - Next-step selection

    /// Deterministic "Next to review" pointer. Prefers checklist
    /// items (quick wins) before lessons; both respect catalogue
    /// order. After every checklist item and every lesson is
    /// completed, the knowledge-check quiz (when present) becomes
    /// the next step until it has been passed. Returns `nil` when
    /// the region is fully reviewed.
    @MainActor
    static func nextStep(
        for bundle: TaxEducationRegionBundle,
        in records: [TaxEducationProgressRecord]
    ) -> TaxEducationNextStep? {
        let region = bundle.region

        for item in bundle.checklist.items {
            let itemStatus = status(
                forChecklistItemID: item.id,
                region: region,
                in: records
            )
            if itemStatus != .completed {
                return TaxEducationNextStep(
                    id: "checklist-\(region.rawValue)-\(item.id)",
                    region: region,
                    kind: .checklistItem,
                    title: item.text,
                    subtitle: "",
                    checklistItemID: item.id
                )
            }
        }

        for lesson in bundle.lessons {
            let lessonStatus = status(
                forLessonID: lesson.id,
                region: region,
                in: records
            )
            if lessonStatus != .completed {
                return TaxEducationNextStep(
                    id: "lesson-\(region.rawValue)-\(lesson.id)",
                    region: region,
                    kind: .lesson,
                    title: lesson.title,
                    subtitle: lesson.whatItIs,
                    lessonID: lesson.id
                )
            }
        }

        if let quiz = bundle.quiz {
            let quizStatus = status(forQuizID: quiz.id, region: region, in: records)
            if quizStatus != .completed {
                return TaxEducationNextStep(
                    id: "quiz-\(region.rawValue)-\(quiz.id)",
                    region: region,
                    kind: .quiz,
                    title: quiz.title,
                    subtitle: quiz.summary,
                    quizID: quiz.id
                )
            }
        }

        return nil
    }

    // MARK: - Quiz unlock + writes

    /// Returns `true` when the user has completed every lesson
    /// and checklist item for the region — the quiz unlock
    /// condition. Pure; mirrors the test harness.
    @MainActor
    static func isQuizUnlocked(
        for bundle: TaxEducationRegionBundle,
        in records: [TaxEducationProgressRecord]
    ) -> Bool {
        guard bundle.quiz != nil else { return false }
        return summary(for: bundle, in: records).hasCompletedLessonsAndChecklist
    }

    /// Persists an explicit quiz attempt. Upserts a single record
    /// keyed on (region, .quiz, quizID). A passing result flips
    /// the record to `.completed`; a failing result keeps it as
    /// `.inProgress` so the UI can surface "needs review" until a
    /// later retake passes.
    @MainActor
    @discardableResult
    static func recordQuizAttempt(
        _ result: TaxEducationQuizResult,
        in modelContext: ModelContext,
        existing records: [TaxEducationProgressRecord]
    ) -> TaxEducationProgressRecord {
        let newStatus: TaxEducationProgressStatus = result.didPass ? .completed : .inProgress
        let matching = records.first { record in
            record.kindRawValue == TaxEducationProgressKind.quiz.rawValue
                && record.regionRawValue == result.region.rawValue
                && record.quizID == result.quizID
        }

        if let existing = matching {
            existing.statusRawValue = newStatus.rawValue
            existing.lastInteractedAt = result.attemptedAt
            existing.quizScorePercent = result.scorePercent
            existing.quizCorrectCount = result.correctCount
            existing.quizQuestionCount = result.questionCount
            save(modelContext)
            return existing
        }

        let record = TaxEducationProgressRecord(
            regionRawValue: result.region.rawValue,
            kindRawValue: TaxEducationProgressKind.quiz.rawValue,
            lessonID: "",
            checklistItemID: "",
            quizID: result.quizID,
            quizScorePercent: result.scorePercent,
            quizCorrectCount: result.correctCount,
            quizQuestionCount: result.questionCount,
            statusRawValue: newStatus.rawValue,
            lastInteractedAt: result.attemptedAt
        )
        modelContext.insert(record)
        save(modelContext)
        return record
    }

    // MARK: - Writes

    /// Marks a lesson reviewed. Idempotent — calling twice on the
    /// same lesson leaves a single record whose
    /// `lastInteractedAt` advances.
    @MainActor
    @discardableResult
    static func markLessonReviewed(
        _ lesson: TaxEducationLesson,
        in modelContext: ModelContext,
        existing records: [TaxEducationProgressRecord],
        now: Date = .now
    ) -> TaxEducationProgressRecord {
        upsert(
            kind: .lesson,
            region: lesson.region,
            lessonID: lesson.id,
            checklistItemID: "",
            status: .completed,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    /// Marks a lesson explicitly not-started — reverses a previous
    /// "Mark reviewed" action. The record is kept so the UI can
    /// show *when* it was reset.
    @MainActor
    @discardableResult
    static func unmarkLessonReviewed(
        _ lesson: TaxEducationLesson,
        in modelContext: ModelContext,
        existing records: [TaxEducationProgressRecord],
        now: Date = .now
    ) -> TaxEducationProgressRecord {
        upsert(
            kind: .lesson,
            region: lesson.region,
            lessonID: lesson.id,
            checklistItemID: "",
            status: .notStarted,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    /// Flips a checklist item between `.notStarted` and
    /// `.completed`. No `.inProgress` transitions in 7B — the UI
    /// stays a two-state checkbox.
    @MainActor
    @discardableResult
    static func toggleChecklistItem(
        _ item: TaxEducationChecklistItem,
        region: TaxEducationRegion,
        in modelContext: ModelContext,
        existing records: [TaxEducationProgressRecord],
        now: Date = .now
    ) -> TaxEducationProgressRecord {
        let current = status(
            forChecklistItemID: item.id,
            region: region,
            in: records
        )
        let newStatus: TaxEducationProgressStatus = current == .completed
            ? .notStarted
            : .completed
        return upsert(
            kind: .checklistItem,
            region: region,
            lessonID: "",
            checklistItemID: item.id,
            status: newStatus,
            in: modelContext,
            existing: records,
            now: now
        )
    }

    // MARK: - Upsert

    @MainActor
    @discardableResult
    private static func upsert(
        kind: TaxEducationProgressKind,
        region: TaxEducationRegion,
        lessonID: String,
        checklistItemID: String,
        status newStatus: TaxEducationProgressStatus,
        in modelContext: ModelContext,
        existing records: [TaxEducationProgressRecord],
        now: Date
    ) -> TaxEducationProgressRecord {
        let matching = records.first { record in
            record.kindRawValue == kind.rawValue
                && record.regionRawValue == region.rawValue
                && record.lessonID == lessonID
                && record.checklistItemID == checklistItemID
        }

        if let existing = matching {
            existing.statusRawValue = newStatus.rawValue
            existing.lastInteractedAt = now
            save(modelContext)
            return existing
        }

        let record = TaxEducationProgressRecord(
            regionRawValue: region.rawValue,
            kindRawValue: kind.rawValue,
            lessonID: lessonID,
            checklistItemID: checklistItemID,
            statusRawValue: newStatus.rawValue,
            lastInteractedAt: now
        )
        modelContext.insert(record)
        save(modelContext)
        return record
    }

    @MainActor
    private static func save(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save tax education progress: \(error.localizedDescription)")
        }
    }
}
