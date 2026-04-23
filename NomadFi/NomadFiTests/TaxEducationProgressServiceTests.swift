// TaxEducationProgressServiceTests.swift
// NomadFi
//
// End-to-end coverage for the Phase 7B progression layer. Uses
// the full-schema container factory + `@Suite(.serialized)` per
// the project's standard SwiftData test hygiene so the delete /
// insert paths stay off the parallel-init crash class.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct TaxEducationProgressServiceTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func usBundle() -> TaxEducationRegionBundle {
        TaxEducationRegionBundle(
            region: .unitedStates,
            isHome: true,
            checklist: TaxEducationCatalog.checklist(for: .unitedStates),
            lessons: TaxEducationCatalog.lessons(for: .unitedStates)
        )
    }

    private func fetchRecords(
        _ context: ModelContext
    ) throws -> [TaxEducationProgressRecord] {
        try context.fetch(
            FetchDescriptor<TaxEducationProgressRecord>(
                sortBy: [SortDescriptor(\TaxEducationProgressRecord.lastInteractedAt, order: .reverse)]
            )
        )
    }

    // MARK: - Defaults

    @Test("Lessons and checklist items read as .notStarted before any record exists")
    func defaultStatusIsNotStarted() throws {
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)
        let item = try #require(bundle.checklist.items.first)

        #expect(
            TaxEducationProgressService.status(
                forLessonID: lesson.id,
                region: bundle.region,
                in: []
            ) == .notStarted
        )
        #expect(
            TaxEducationProgressService.status(
                forChecklistItemID: item.id,
                region: bundle.region,
                in: []
            ) == .notStarted
        )
    }

    // MARK: - Lesson review persistence

    @Test("markLessonReviewed persists and survives a re-fetch")
    func markLessonReviewedPersists() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        TaxEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: [],
            now: now
        )

        var records = try fetchRecords(context)
        #expect(records.count == 1)
        #expect(records[0].status == .completed)
        #expect(records[0].lessonID == lesson.id)
        #expect(records[0].lastInteractedAt == now)

        // Re-run the lookup against a re-fetched list — should
        // still read .completed.
        records = try fetchRecords(context)
        let status = TaxEducationProgressService.status(
            forLessonID: lesson.id,
            region: bundle.region,
            in: records
        )
        #expect(status == .completed)
    }

    @Test("markLessonReviewed is idempotent — two calls produce exactly one record")
    func markLessonReviewedIsIdempotent() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)

        TaxEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: []
        )
        let firstRecords = try fetchRecords(context)
        TaxEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: firstRecords
        )

        let finalRecords = try fetchRecords(context)
        #expect(finalRecords.count == 1)
        #expect(finalRecords[0].status == .completed)
    }

    @Test("unmarkLessonReviewed reverts an existing record to .notStarted")
    func unmarkLessonReviewedReverts() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)

        TaxEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: []
        )
        var records = try fetchRecords(context)
        TaxEducationProgressService.unmarkLessonReviewed(
            lesson,
            in: context,
            existing: records
        )

        records = try fetchRecords(context)
        #expect(records.count == 1)
        let status = TaxEducationProgressService.status(
            forLessonID: lesson.id,
            region: bundle.region,
            in: records
        )
        #expect(status == .notStarted)
    }

    // MARK: - Checklist toggle

    @Test("toggleChecklistItem flips between completed and not-started and persists")
    func toggleChecklistItemFlipsState() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let item = try #require(bundle.checklist.items.first)

        // First toggle → completed.
        TaxEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: []
        )
        var records = try fetchRecords(context)
        #expect(
            TaxEducationProgressService.status(
                forChecklistItemID: item.id,
                region: bundle.region,
                in: records
            ) == .completed
        )

        // Second toggle → notStarted.
        TaxEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: records
        )
        records = try fetchRecords(context)
        #expect(
            TaxEducationProgressService.status(
                forChecklistItemID: item.id,
                region: bundle.region,
                in: records
            ) == .notStarted
        )
        #expect(records.count == 1)
    }

    // MARK: - Cross-region isolation

    @Test("Marking a US lesson reviewed does not leak into Canada's status")
    func regionIsolationIsHonoured() throws {
        let context = try makeContext()
        let usLesson = try #require(TaxEducationCatalog.lessons(for: .unitedStates).first)

        TaxEducationProgressService.markLessonReviewed(
            usLesson,
            in: context,
            existing: []
        )
        let records = try fetchRecords(context)

        #expect(
            TaxEducationProgressService.status(
                forLessonID: usLesson.id,
                region: .unitedStates,
                in: records
            ) == .completed
        )
        #expect(
            TaxEducationProgressService.status(
                forLessonID: usLesson.id,
                region: .canada,
                in: records
            ) == .notStarted
        )
    }

    // MARK: - Summaries

    @Test("Region progress summary counts lessons and checklist items separately, then rolls up")
    func summaryCountsAreCorrect() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let firstLesson = try #require(bundle.lessons.first)
        let firstItem = try #require(bundle.checklist.items.first)

        // No progress yet.
        var records = try fetchRecords(context)
        var summary = TaxEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.lessonsReviewed == 0)
        #expect(summary.checklistItemsCompleted == 0)
        #expect(summary.stepsReviewed == 0)
        #expect(summary.stepsTotal == bundle.lessons.count + bundle.checklist.items.count)
        #expect(summary.isReviewed == false)

        // One lesson + one checklist item done.
        TaxEducationProgressService.markLessonReviewed(
            firstLesson,
            in: context,
            existing: records
        )
        records = try fetchRecords(context)
        TaxEducationProgressService.toggleChecklistItem(
            firstItem,
            region: bundle.region,
            in: context,
            existing: records
        )

        records = try fetchRecords(context)
        summary = TaxEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.lessonsReviewed == 1)
        #expect(summary.checklistItemsCompleted == 1)
        #expect(summary.stepsReviewed == 2)
        #expect(summary.isReviewed == false)
    }

    // MARK: - Next step selection

    @Test("Next step prefers the first uncompleted checklist item before any lesson")
    func nextStepPrefersChecklist() throws {
        let context = try makeContext()
        let bundle = usBundle()

        let records = try fetchRecords(context)
        let next = TaxEducationProgressService.nextStep(for: bundle, in: records)
        let step = try #require(next)
        #expect(step.kind == .checklistItem)
        #expect(step.region == .unitedStates)
        #expect(step.checklistItemID == bundle.checklist.items.first?.id)
    }

    @Test("Next step falls through to the first uncompleted lesson after every checklist item is done")
    func nextStepFallsThroughToLessons() throws {
        let context = try makeContext()
        let bundle = usBundle()

        for item in bundle.checklist.items {
            let records = try fetchRecords(context)
            TaxEducationProgressService.toggleChecklistItem(
                item,
                region: bundle.region,
                in: context,
                existing: records
            )
        }

        let records = try fetchRecords(context)
        let next = TaxEducationProgressService.nextStep(for: bundle, in: records)
        let step = try #require(next)
        #expect(step.kind == .lesson)
        #expect(step.lessonID == bundle.lessons.first?.id)
    }

    @Test("Next step is nil when every lesson and every checklist item is completed")
    func nextStepNilWhenFullyReviewed() throws {
        let context = try makeContext()
        let bundle = usBundle()

        for item in bundle.checklist.items {
            let records = try fetchRecords(context)
            TaxEducationProgressService.toggleChecklistItem(
                item,
                region: bundle.region,
                in: context,
                existing: records
            )
        }
        for lesson in bundle.lessons {
            let records = try fetchRecords(context)
            TaxEducationProgressService.markLessonReviewed(
                lesson,
                in: context,
                existing: records
            )
        }

        let records = try fetchRecords(context)
        let next = TaxEducationProgressService.nextStep(for: bundle, in: records)
        #expect(next == nil)

        let summary = TaxEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.isReviewed == true)
    }

    // MARK: - Safety

    @Test("Generating the summary and next step never mutates the records or writes to SwiftData")
    func readPathsAreSideEffectFree() throws {
        let context = try makeContext()
        let bundle = usBundle()

        let before = try fetchRecords(context)
        _ = TaxEducationProgressService.summary(for: bundle, in: before)
        _ = TaxEducationProgressService.nextStep(for: bundle, in: before)
        let after = try fetchRecords(context)
        #expect(before.count == after.count)
    }

    // MARK: - Copy guard

    @Test("Summary captions and next-step titles never use banned tax / compliance vocabulary")
    func copyGuardOnProgressCopy() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let bannedPhrases: [String] = [
            "You're done with taxes",
            "compliant",
            "you qualify",
            "you're qualified",
            "this qualifies",
            "tax advice",
            "legal advice",
            "immigration advice",
        ]

        var inspected: [String] = []

        // Empty state.
        var records = try fetchRecords(context)
        var summary = TaxEducationProgressService.summary(for: bundle, in: records)
        inspected.append(summary.displayCaption)
        if let step = TaxEducationProgressService.nextStep(for: bundle, in: records) {
            inspected.append(step.title)
            inspected.append(step.subtitle)
        }

        // Full state.
        for item in bundle.checklist.items {
            records = try fetchRecords(context)
            TaxEducationProgressService.toggleChecklistItem(
                item,
                region: bundle.region,
                in: context,
                existing: records
            )
        }
        for lesson in bundle.lessons {
            records = try fetchRecords(context)
            TaxEducationProgressService.markLessonReviewed(
                lesson,
                in: context,
                existing: records
            )
        }
        records = try fetchRecords(context)
        summary = TaxEducationProgressService.summary(for: bundle, in: records)
        inspected.append(summary.displayCaption)
        if let step = TaxEducationProgressService.nextStep(for: bundle, in: records) {
            inspected.append(step.title)
            inspected.append(step.subtitle)
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in progress copy: \(copy)"
                )
            }
        }
    }
}
