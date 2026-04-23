// TaxEducationQuizServiceTests.swift
// NomadFi
//
// End-to-end coverage for the Phase 7C quiz persistence layer.
// Uses the full-schema container factory + `@Suite(.serialized)`
// so the delete / insert paths stay off the parallel-init crash
// class.
//
// The contract pinned here:
//   • Quiz status defaults to .notStarted when no record exists.
//   • A failing attempt persists .inProgress with the score.
//   • A passing attempt persists .completed.
//   • Retakes overwrite the single record for the (region, quizID)
//     tuple — never duplicate rows.
//   • Unlock rule: quiz reads as locked until every lesson and
//     every checklist item for the region is completed.
//   • Next-step priority after unlock: checklist → lessons → quiz.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct TaxEducationQuizServiceTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func usBundle() -> TaxEducationRegionBundle {
        TaxEducationRegionBundle(
            region: .unitedStates,
            isHome: true,
            checklist: TaxEducationCatalog.checklist(for: .unitedStates),
            lessons: TaxEducationCatalog.lessons(for: .unitedStates),
            quiz: TaxEducationQuizCatalog.quiz(for: .unitedStates)
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

    private func markAllLessonsAndChecklistComplete(
        bundle: TaxEducationRegionBundle,
        in context: ModelContext
    ) throws {
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
    }

    // MARK: - Defaults

    @Test("A quiz reads as .notStarted before any attempt")
    func defaultQuizStatusIsNotStarted() throws {
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)
        #expect(
            TaxEducationProgressService.status(
                forQuizID: quiz.id,
                region: bundle.region,
                in: []
            ) == .notStarted
        )
    }

    // MARK: - Unlock rule

    @Test("The quiz is locked while any lesson or checklist item is still outstanding")
    func quizLockedWhileItemsOutstanding() throws {
        let context = try makeContext()
        let bundle = usBundle()
        #expect(
            TaxEducationProgressService.isQuizUnlocked(
                for: bundle,
                in: try fetchRecords(context)
            ) == false
        )

        // Only a few items complete — still locked.
        let records = try fetchRecords(context)
        if let firstItem = bundle.checklist.items.first {
            TaxEducationProgressService.toggleChecklistItem(
                firstItem,
                region: bundle.region,
                in: context,
                existing: records
            )
        }
        #expect(
            TaxEducationProgressService.isQuizUnlocked(
                for: bundle,
                in: try fetchRecords(context)
            ) == false
        )
    }

    @Test("Once every lesson and checklist item is complete, the quiz unlocks")
    func quizUnlocksAfterAllItemsComplete() throws {
        let context = try makeContext()
        let bundle = usBundle()
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)
        #expect(
            TaxEducationProgressService.isQuizUnlocked(
                for: bundle,
                in: try fetchRecords(context)
            ) == true
        )
    }

    // MARK: - Next-step fallthrough

    @Test("After the checklist and lessons are complete, nextStep falls through to the quiz")
    func nextStepFallsThroughToQuiz() throws {
        let context = try makeContext()
        let bundle = usBundle()
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)

        let next = TaxEducationProgressService.nextStep(
            for: bundle,
            in: try fetchRecords(context)
        )
        let step = try #require(next)
        #expect(step.kind == .quiz)
        #expect(step.quizID == bundle.quiz?.id)
    }

    @Test("Once the quiz passes, nextStep is nil for the region")
    func nextStepNilWhenQuizPasses() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)

        let passing = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            passing,
            in: context,
            existing: try fetchRecords(context)
        )

        let next = TaxEducationProgressService.nextStep(
            for: bundle,
            in: try fetchRecords(context)
        )
        #expect(next == nil)
    }

    // MARK: - Persistence

    @Test("A failing attempt persists the score with .inProgress status")
    func failingAttemptPersistsInProgress() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)
        let result = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: 1,
            questionCount: quiz.questionCount,
            scorePercent: 33.3,
            didPass: false,
            attemptedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        TaxEducationProgressService.recordQuizAttempt(
            result,
            in: context,
            existing: try fetchRecords(context)
        )

        let records = try fetchRecords(context)
        let quizRecords = records.filter {
            $0.kindRawValue == TaxEducationProgressKind.quiz.rawValue
        }
        #expect(quizRecords.count == 1)
        #expect(quizRecords[0].status == .inProgress)
        #expect(quizRecords[0].quizScorePercent == 33.3)
        #expect(quizRecords[0].quizCorrectCount == 1)
    }

    @Test("A passing attempt persists the score with .completed status")
    func passingAttemptPersistsCompleted() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)
        let result = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        TaxEducationProgressService.recordQuizAttempt(
            result,
            in: context,
            existing: try fetchRecords(context)
        )

        let records = try fetchRecords(context)
        let quizRecord = try #require(records.first { $0.kindRawValue == TaxEducationProgressKind.quiz.rawValue })
        #expect(quizRecord.status == .completed)
        #expect(quizRecord.quizScorePercent == 100)
    }

    @Test("Retakes update the existing record in place — no duplicate rows")
    func retakeOverwritesExistingRecord() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)

        // First attempt — fail.
        let fail = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: 1,
            questionCount: quiz.questionCount,
            scorePercent: 33.3,
            didPass: false,
            attemptedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        TaxEducationProgressService.recordQuizAttempt(
            fail,
            in: context,
            existing: try fetchRecords(context)
        )

        // Retake — pass.
        let pass = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        TaxEducationProgressService.recordQuizAttempt(
            pass,
            in: context,
            existing: try fetchRecords(context)
        )

        let quizRecords = try fetchRecords(context).filter {
            $0.kindRawValue == TaxEducationProgressKind.quiz.rawValue
        }
        #expect(quizRecords.count == 1)
        #expect(quizRecords[0].status == .completed)
        #expect(quizRecords[0].quizScorePercent == 100)
        #expect(quizRecords[0].lastInteractedAt == Date(timeIntervalSince1970: 1_900_000_000))
    }

    // MARK: - Summary

    @Test("Per-region summary reflects quiz status + counts the quiz as one additional step")
    func summaryIncludesQuizState() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)

        // Before unlock / attempts.
        var summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        #expect(summary.hasQuiz == true)
        #expect(summary.quizStatus == .notStarted)
        #expect(summary.stepsTotal == bundle.lessons.count + bundle.checklist.items.count + 1)
        #expect(summary.isReviewed == false)

        // After everything + a passing attempt.
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)
        let passing = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            passing,
            in: context,
            existing: try fetchRecords(context)
        )
        summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        #expect(summary.quizStatus == .completed)
        #expect(summary.quizPassed == true)
        #expect(summary.quizScorePercent == 100)
        #expect(summary.stepsReviewed == summary.stepsTotal)
        #expect(summary.isReviewed == true)
    }

    @Test("A failing attempt flips the summary into an attempted-not-passed state that needs retaking")
    func summaryReflectsFailingAttempt() throws {
        let context = try makeContext()
        let bundle = usBundle()
        let quiz = try #require(bundle.quiz)
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)

        let failed = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: 1,
            questionCount: quiz.questionCount,
            scorePercent: 33.3,
            didPass: false,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            failed,
            in: context,
            existing: try fetchRecords(context)
        )

        let summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        #expect(summary.quizStatus == .inProgress)
        #expect(summary.quizAttemptedNotPassed == true)
        #expect(summary.isReviewed == false)
    }

    // MARK: - Region isolation

    @Test("Marking one region's quiz passed does not leak into another region's quiz status")
    func regionIsolation() throws {
        let context = try makeContext()
        let usBundle = usBundle()
        let usQuiz = try #require(usBundle.quiz)
        let passingUS = TaxEducationQuizResult(
            quizID: usQuiz.id,
            region: usBundle.region,
            correctCount: usQuiz.questionCount,
            questionCount: usQuiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            passingUS,
            in: context,
            existing: try fetchRecords(context)
        )

        let records = try fetchRecords(context)
        let caStatus = TaxEducationProgressService.status(
            forQuizID: "ca-knowledge-check",
            region: .canada,
            in: records
        )
        #expect(caStatus == .notStarted)
    }

    // MARK: - Copy guard (progress summary + next step)

    @Test("Progress summary captions + next-step titles never introduce banned vocabulary once a quiz is in play")
    func copyGuardForProgressAndNextStepWithQuiz() throws {
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

        // Unlock and record a failing + passing attempt to cover
        // every summary caption shape.
        try markAllLessonsAndChecklistComplete(bundle: bundle, in: context)
        let quiz = try #require(bundle.quiz)

        // Pending-first caption.
        var summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        inspected.append(summary.displayCaption)
        if let step = TaxEducationProgressService.nextStep(
            for: bundle,
            in: try fetchRecords(context)
        ) {
            inspected.append(step.title)
            inspected.append(step.subtitle)
        }

        // Failing attempt caption.
        let failed = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: 1,
            questionCount: quiz.questionCount,
            scorePercent: 33.3,
            didPass: false,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            failed,
            in: context,
            existing: try fetchRecords(context)
        )
        summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        inspected.append(summary.displayCaption)

        // Passing retake.
        let passing = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            passing,
            in: context,
            existing: try fetchRecords(context)
        )
        summary = TaxEducationProgressService.summary(
            for: bundle,
            in: try fetchRecords(context)
        )
        inspected.append(summary.displayCaption)

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in progress / next-step copy: \(copy)"
                )
            }
        }
    }
}
