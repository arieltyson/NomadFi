// InvestingEducationProgressService.swift
// NomadFi
//
// Pure read + explicit write service for the Phase 8A investing-
// education progression. Mirrors the read/write rules of
// `TaxEducationProgressService`:
//
//   • A lesson with no matching record reads as `.notStarted`.
//   • A checklist item with no matching record reads as
//     `.notStarted`.
//   • `markLessonReviewed(...)` is idempotent — calling twice on the
//     same lesson produces exactly one record.
//   • `toggleChecklistItem(...)` flips between `.notStarted` and
//     `.completed`; no `.inProgress` state in 8A.
//   • Next-step priority: first uncompleted checklist item in the
//     region's checklist order, then first uncompleted lesson in
//     the region's lesson order, then `nil` once everything is
//     reviewed.
//   • Duplicate persisted records for the same key are tolerated:
//     reads treat the newest `.completed` entry as authoritative.

import Foundation
import OSLog
import SwiftData

enum InvestingEducationProgressService {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "InvestingEducationProgress"
    )

    // MARK: - Status lookup

    @MainActor
    static func status(
        forLessonID lessonID: String,
        region: InvestingEducationRegion,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationProgressStatus {
        let matches = records.filter { record in
            record.kindRawValue == InvestingEducationProgressKind.lesson.rawValue
                && record.regionRawValue == region.rawValue
                && record.lessonID == lessonID
        }
        return resolveStatus(from: matches)
    }

    @MainActor
    static func status(
        forChecklistItemID itemID: String,
        region: InvestingEducationRegion,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationProgressStatus {
        let matches = records.filter { record in
            record.kindRawValue == InvestingEducationProgressKind.checklistItem.rawValue
                && record.regionRawValue == region.rawValue
                && record.checklistItemID == itemID
        }
        return resolveStatus(from: matches)
    }

    private static func resolveStatus(
        from matches: [InvestingEducationProgressRecord]
    ) -> InvestingEducationProgressStatus {
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

    @MainActor
    static func summary(
        for bundle: InvestingEducationRegionBundle,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationRegionProgressSummary {
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

        return InvestingEducationRegionProgressSummary(
            region: region,
            lessonsReviewed: lessonsReviewed,
            lessonsTotal: bundle.lessons.count,
            checklistItemsCompleted: checklistCompleted,
            checklistItemsTotal: bundle.checklist.items.count
        )
    }

    // MARK: - Next step

    @MainActor
    static func nextStep(
        for bundle: InvestingEducationRegionBundle,
        in records: [InvestingEducationProgressRecord]
    ) -> InvestingEducationNextStep? {
        let region = bundle.region

        for item in bundle.checklist.items {
            let itemStatus = status(
                forChecklistItemID: item.id,
                region: region,
                in: records
            )
            if itemStatus != .completed {
                return InvestingEducationNextStep(
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
                return InvestingEducationNextStep(
                    id: "lesson-\(region.rawValue)-\(lesson.id)",
                    region: region,
                    kind: .lesson,
                    title: lesson.title,
                    subtitle: lesson.whatItIs,
                    lessonID: lesson.id
                )
            }
        }

        return nil
    }

    // MARK: - Writes

    @MainActor
    @discardableResult
    static func markLessonReviewed(
        _ lesson: InvestingEducationLesson,
        in modelContext: ModelContext,
        existing records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) -> InvestingEducationProgressRecord {
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

    @MainActor
    @discardableResult
    static func unmarkLessonReviewed(
        _ lesson: InvestingEducationLesson,
        in modelContext: ModelContext,
        existing records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) -> InvestingEducationProgressRecord {
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

    @MainActor
    @discardableResult
    static func toggleChecklistItem(
        _ item: InvestingEducationChecklistItem,
        region: InvestingEducationRegion,
        in modelContext: ModelContext,
        existing records: [InvestingEducationProgressRecord],
        now: Date = .now
    ) -> InvestingEducationProgressRecord {
        let current = status(
            forChecklistItemID: item.id,
            region: region,
            in: records
        )
        let newStatus: InvestingEducationProgressStatus = current == .completed
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
        kind: InvestingEducationProgressKind,
        region: InvestingEducationRegion,
        lessonID: String,
        checklistItemID: String,
        status newStatus: InvestingEducationProgressStatus,
        in modelContext: ModelContext,
        existing records: [InvestingEducationProgressRecord],
        now: Date
    ) -> InvestingEducationProgressRecord {
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

        let record = InvestingEducationProgressRecord(
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
            logger.error(
                "Failed to save investing education progress: \(error.localizedDescription)"
            )
        }
    }
}
