// InvestingEducationProgressServiceTests.swift
// NomadFi
//
// End-to-end coverage for the Phase 8A progression layer. Uses the
// full-schema container factory + `@Suite(.serialized)` per the
// project's standard SwiftData test hygiene so the delete / insert
// paths stay off the parallel-init crash class.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct InvestingEducationProgressServiceTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func usBundle() -> InvestingEducationRegionBundle {
        InvestingEducationRegionBundle(
            region: .unitedStates,
            isHome: true,
            checklist: InvestingEducationCatalog.checklist(for: .unitedStates),
            lessons: InvestingEducationCatalog.lessons(for: .unitedStates)
        )
    }

    private func fetchRecords(
        _ context: ModelContext
    ) throws -> [InvestingEducationProgressRecord] {
        try context.fetch(
            FetchDescriptor<InvestingEducationProgressRecord>(
                sortBy: [SortDescriptor(\InvestingEducationProgressRecord.lastInteractedAt, order: .reverse)]
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
            InvestingEducationProgressService.status(
                forLessonID: lesson.id,
                region: bundle.region,
                in: []
            ) == .notStarted
        )
        #expect(
            InvestingEducationProgressService.status(
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

        InvestingEducationProgressService.markLessonReviewed(
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

        records = try fetchRecords(context)
        let status = InvestingEducationProgressService.status(
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

        InvestingEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: []
        )
        let firstRecords = try fetchRecords(context)
        InvestingEducationProgressService.markLessonReviewed(
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

        InvestingEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: []
        )
        var records = try fetchRecords(context)
        InvestingEducationProgressService.unmarkLessonReviewed(
            lesson,
            in: context,
            existing: records
        )

        records = try fetchRecords(context)
        #expect(records.count == 1)
        let status = InvestingEducationProgressService.status(
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

        InvestingEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: []
        )
        var records = try fetchRecords(context)
        #expect(
            InvestingEducationProgressService.status(
                forChecklistItemID: item.id,
                region: bundle.region,
                in: records
            ) == .completed
        )

        InvestingEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: records
        )
        records = try fetchRecords(context)
        #expect(
            InvestingEducationProgressService.status(
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
        let usLesson = try #require(InvestingEducationCatalog.lessons(for: .unitedStates).first)

        InvestingEducationProgressService.markLessonReviewed(
            usLesson,
            in: context,
            existing: []
        )
        let records = try fetchRecords(context)

        #expect(
            InvestingEducationProgressService.status(
                forLessonID: usLesson.id,
                region: .unitedStates,
                in: records
            ) == .completed
        )
        #expect(
            InvestingEducationProgressService.status(
                forLessonID: usLesson.id,
                region: .canada,
                in: records
            ) == .notStarted
        )
    }

    // MARK: - Tax / investing isolation

    @Test("Investing progress does not share storage with the tax-education progression")
    func investingDoesNotLeakIntoTaxRecords() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)

        InvestingEducationProgressService.markLessonReviewed(
            lesson,
            in: context,
            existing: []
        )

        let taxRecords = try context.fetch(
            FetchDescriptor<TaxEducationProgressRecord>()
        )
        #expect(
            taxRecords.isEmpty,
            "Investing writes must never create TaxEducationProgressRecord rows."
        )
    }

    // MARK: - Summaries

    @Test("Region progress summary counts lessons and checklist items separately, then rolls up")
    func summaryCountsAreCorrect() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let firstLesson = try #require(bundle.lessons.first)
        let firstItem = try #require(bundle.checklist.items.first)

        var records = try fetchRecords(context)
        var summary = InvestingEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.lessonsReviewed == 0)
        #expect(summary.checklistItemsCompleted == 0)
        #expect(summary.totalCompleted == 0)
        #expect(summary.totalTrackable == bundle.lessons.count + bundle.checklist.items.count)
        #expect(summary.hasCompletedLessonsAndChecklist == false)

        InvestingEducationProgressService.markLessonReviewed(
            firstLesson,
            in: context,
            existing: records
        )
        records = try fetchRecords(context)
        InvestingEducationProgressService.toggleChecklistItem(
            firstItem,
            region: bundle.region,
            in: context,
            existing: records
        )

        records = try fetchRecords(context)
        summary = InvestingEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.lessonsReviewed == 1)
        #expect(summary.checklistItemsCompleted == 1)
        #expect(summary.totalCompleted == 2)
        #expect(summary.hasCompletedLessonsAndChecklist == false)
    }

    // MARK: - Next step selection

    @Test("Next step prefers the first uncompleted checklist item before any lesson")
    func nextStepPrefersChecklist() throws {
        let context = try makeContext()
        let bundle = usBundle()

        let records = try fetchRecords(context)
        let next = InvestingEducationProgressService.nextStep(for: bundle, in: records)
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
            InvestingEducationProgressService.toggleChecklistItem(
                item,
                region: bundle.region,
                in: context,
                existing: records
            )
        }

        let records = try fetchRecords(context)
        let next = InvestingEducationProgressService.nextStep(for: bundle, in: records)
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
            InvestingEducationProgressService.toggleChecklistItem(
                item,
                region: bundle.region,
                in: context,
                existing: records
            )
        }
        for lesson in bundle.lessons {
            let records = try fetchRecords(context)
            InvestingEducationProgressService.markLessonReviewed(
                lesson,
                in: context,
                existing: records
            )
        }

        let records = try fetchRecords(context)
        let next = InvestingEducationProgressService.nextStep(for: bundle, in: records)
        #expect(next == nil)

        let summary = InvestingEducationProgressService.summary(for: bundle, in: records)
        #expect(summary.hasCompletedLessonsAndChecklist == true)
    }

    // MARK: - Safety

    @Test("Generating the summary and next step never mutates the records or writes to SwiftData")
    func readPathsAreSideEffectFree() throws {
        let context = try makeContext()
        let bundle = usBundle()

        let before = try fetchRecords(context)
        _ = InvestingEducationProgressService.summary(for: bundle, in: before)
        _ = InvestingEducationProgressService.nextStep(for: bundle, in: before)
        let after = try fetchRecords(context)
        #expect(before.count == after.count)
    }

    // MARK: - Duplicate-record tolerance

    @Test("Duplicate persisted records collapse: any .completed entry wins for status reads")
    func duplicateRecordsCompletedWins() throws {
        let bundle = usBundle()
        let lesson = try #require(bundle.lessons.first)
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_800_000_000)

        let completedRecord = InvestingEducationProgressRecord(
            regionRawValue: bundle.region.rawValue,
            kindRawValue: InvestingEducationProgressKind.lesson.rawValue,
            lessonID: lesson.id,
            statusRawValue: InvestingEducationProgressStatus.completed.rawValue,
            lastInteractedAt: earlier
        )
        let notStartedRecord = InvestingEducationProgressRecord(
            regionRawValue: bundle.region.rawValue,
            kindRawValue: InvestingEducationProgressKind.lesson.rawValue,
            lessonID: lesson.id,
            statusRawValue: InvestingEducationProgressStatus.notStarted.rawValue,
            lastInteractedAt: later
        )

        let status = InvestingEducationProgressService.status(
            forLessonID: lesson.id,
            region: bundle.region,
            in: [completedRecord, notStartedRecord]
        )
        #expect(status == .completed)
    }
}
