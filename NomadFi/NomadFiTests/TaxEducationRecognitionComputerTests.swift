// TaxEducationRecognitionComputerTests.swift
// NomadFi
//
// End-to-end coverage for the calm recognition computer. Uses the
// full-schema container factory + `@Suite(.serialized)` per the
// project's standard SwiftData hygiene so progress inserts do not
// race the parallel-init path.
//
// The product contract pinned here:
//   • Recognition is derived, not persisted — regressing progress
//     drops the corresponding badges on the next refresh.
//   • `.firstStepReviewed` fires for any explicit completion.
//   • `.starterReviewed` fires on lessons + checklist, no quiz.
//   • `.knowledgeCheckPassed` fires only on a passing quiz.
//   • `.regionReviewed` requires `summary.isReviewed`, which
//     includes the quiz when present.
//   • `.multiRegionReviewed` requires two regions in
//     `regionReviewed` state.
//   • No banned vocabulary anywhere in badge copy.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct TaxEducationRecognitionComputerTests {

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

    private func caBundle() -> TaxEducationRegionBundle {
        TaxEducationRegionBundle(
            region: .canada,
            isHome: false,
            checklist: TaxEducationCatalog.checklist(for: .canada),
            lessons: TaxEducationCatalog.lessons(for: .canada),
            quiz: TaxEducationQuizCatalog.quiz(for: .canada)
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

    private func completeLessonsAndChecklist(
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

    private func passQuiz(
        bundle: TaxEducationRegionBundle,
        in context: ModelContext
    ) throws {
        guard let quiz = bundle.quiz else {
            Issue.record("Bundle for \(bundle.region.displayName) has no quiz.")
            return
        }
        let result = TaxEducationQuizResult(
            quizID: quiz.id,
            region: bundle.region,
            correctCount: quiz.questionCount,
            questionCount: quiz.questionCount,
            scorePercent: 100,
            didPass: true,
            attemptedAt: .now
        )
        TaxEducationProgressService.recordQuizAttempt(
            result,
            in: context,
            existing: try fetchRecords(context)
        )
    }

    // MARK: - Empty baseline

    @Test("Empty jurisdictions → empty summary")
    func emptyJurisdictionsYieldNoRecognition() {
        let summary = TaxEducationRecognitionComputer.summary(for: [], in: [])
        #expect(summary.isEmpty)
        #expect(summary.portfolioBadges.isEmpty)
        #expect(summary.badgesByRegion.isEmpty)
    }

    @Test("Jurisdictions on file but no progress → empty summary")
    func jurisdictionsWithoutProgressYieldNoRecognition() throws {
        let summary = TaxEducationRecognitionComputer.summary(
            for: [usBundle(), caBundle()],
            in: []
        )
        #expect(summary.isEmpty)
    }

    // MARK: - First-step badge

    @Test(".firstStepReviewed appears after a single checklist item is completed")
    func firstStepAppearsAfterAnyExplicitCompletion() throws {
        let context = try makeContext()
        let bundle = usBundle()

        // Toggle exactly one checklist item complete.
        let item = try #require(bundle.checklist.items.first)
        TaxEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: []
        )
        let records = try fetchRecords(context)

        let summary = TaxEducationRecognitionComputer.summary(
            for: [bundle],
            in: records
        )
        let kinds = summary.portfolioBadges.map(\.kind)
        #expect(kinds.contains(.firstStepReviewed))
    }

    @Test(".firstStepReviewed disappears when the only completion is reverted")
    func firstStepDisappearsWhenRegressed() throws {
        let context = try makeContext()
        let bundle = usBundle()

        let item = try #require(bundle.checklist.items.first)
        TaxEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: []
        )
        // Toggle it back off.
        TaxEducationProgressService.toggleChecklistItem(
            item,
            region: bundle.region,
            in: context,
            existing: try fetchRecords(context)
        )

        let summary = TaxEducationRecognitionComputer.summary(
            for: [bundle],
            in: try fetchRecords(context)
        )
        let kinds = summary.portfolioBadges.map(\.kind)
        #expect(!kinds.contains(.firstStepReviewed))
    }

    // MARK: - Starter / knowledge-check / region-reviewed

    @Test(".starterReviewed appears when lessons + checklist are complete — quiz not required")
    func starterAppearsOnLessonsAndChecklistOnly() throws {
        let context = try makeContext()
        let bundle = usBundle()
        try completeLessonsAndChecklist(bundle: bundle, in: context)

        let summary = TaxEducationRecognitionComputer.summary(
            for: [bundle],
            in: try fetchRecords(context)
        )
        let regionBadges = summary.badgesByRegion[bundle.region] ?? []
        let kinds = regionBadges.map(\.kind)
        #expect(kinds.contains(.starterReviewed(.unitedStates)))
        #expect(!kinds.contains(.knowledgeCheckPassed(.unitedStates)))
        #expect(!kinds.contains(.regionReviewed(.unitedStates)))
    }

    @Test(".knowledgeCheckPassed appears only after a passing quiz attempt")
    func knowledgeCheckRequiresPassingAttempt() throws {
        let context = try makeContext()
        let bundle = usBundle()
        try completeLessonsAndChecklist(bundle: bundle, in: context)
        try passQuiz(bundle: bundle, in: context)

        let summary = TaxEducationRecognitionComputer.summary(
            for: [bundle],
            in: try fetchRecords(context)
        )
        let regionBadges = summary.badgesByRegion[bundle.region] ?? []
        let kinds = regionBadges.map(\.kind)
        #expect(kinds.contains(.knowledgeCheckPassed(.unitedStates)))
        #expect(kinds.contains(.regionReviewed(.unitedStates)))
    }

    @Test("A failing quiz does not grant .knowledgeCheckPassed or .regionReviewed")
    func failingQuizDoesNotEarnBadge() throws {
        let context = try makeContext()
        let bundle = usBundle()
        try completeLessonsAndChecklist(bundle: bundle, in: context)

        let quiz = try #require(bundle.quiz)
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

        let summary = TaxEducationRecognitionComputer.summary(
            for: [bundle],
            in: try fetchRecords(context)
        )
        let regionBadges = summary.badgesByRegion[bundle.region] ?? []
        let kinds = regionBadges.map(\.kind)
        #expect(!kinds.contains(.knowledgeCheckPassed(.unitedStates)))
        #expect(!kinds.contains(.regionReviewed(.unitedStates)))
    }

    // MARK: - Multi-region

    @Test(".multiRegionReviewed requires two or more fully-reviewed regions")
    func multiRegionBadgeRequiresTwoCompletedRegions() throws {
        let context = try makeContext()
        let us = usBundle()
        let ca = caBundle()

        // Only US complete — no multi-region badge yet.
        try completeLessonsAndChecklist(bundle: us, in: context)
        try passQuiz(bundle: us, in: context)

        var summary = TaxEducationRecognitionComputer.summary(
            for: [us, ca],
            in: try fetchRecords(context)
        )
        var kinds = summary.portfolioBadges.map(\.kind)
        #expect(!kinds.contains(.multiRegionReviewed))

        // Complete Canada too — multi-region appears.
        try completeLessonsAndChecklist(bundle: ca, in: context)
        try passQuiz(bundle: ca, in: context)

        summary = TaxEducationRecognitionComputer.summary(
            for: [us, ca],
            in: try fetchRecords(context)
        )
        kinds = summary.portfolioBadges.map(\.kind)
        #expect(kinds.contains(.multiRegionReviewed))
    }

    @Test("Regressing a region drops .regionReviewed and .multiRegionReviewed on the next refresh")
    func regressionDropsDerivedBadges() throws {
        let context = try makeContext()
        let us = usBundle()
        let ca = caBundle()

        try completeLessonsAndChecklist(bundle: us, in: context)
        try passQuiz(bundle: us, in: context)
        try completeLessonsAndChecklist(bundle: ca, in: context)
        try passQuiz(bundle: ca, in: context)

        // Unmark one lesson in Canada — should drop .regionReviewed
        // for CA and the portfolio-wide .multiRegionReviewed.
        let lessonToRegress = try #require(ca.lessons.first)
        TaxEducationProgressService.unmarkLessonReviewed(
            lessonToRegress,
            in: context,
            existing: try fetchRecords(context)
        )

        let summary = TaxEducationRecognitionComputer.summary(
            for: [us, ca],
            in: try fetchRecords(context)
        )
        let caKinds = (summary.badgesByRegion[ca.region] ?? []).map(\.kind)
        let portfolioKinds = summary.portfolioBadges.map(\.kind)
        #expect(!caKinds.contains(.regionReviewed(.canada)))
        #expect(!portfolioKinds.contains(.multiRegionReviewed))

        // US region still reviewed.
        let usKinds = (summary.badgesByRegion[us.region] ?? []).map(\.kind)
        #expect(usKinds.contains(.regionReviewed(.unitedStates)))
    }

    // MARK: - Copy guard

    @Test("Badge copy never uses the banned tax / compliance vocabulary")
    func copyGuardOnBadgeVocabulary() throws {
        let context = try makeContext()
        let us = usBundle()
        let ca = caBundle()
        try completeLessonsAndChecklist(bundle: us, in: context)
        try passQuiz(bundle: us, in: context)
        try completeLessonsAndChecklist(bundle: ca, in: context)
        try passQuiz(bundle: ca, in: context)

        let summary = TaxEducationRecognitionComputer.summary(
            for: [us, ca],
            in: try fetchRecords(context)
        )

        let bannedPhrases: [String] = [
            "You're done with taxes",
            "compliant",
            "streak",
            "you qualify",
            "you're qualified",
            "this qualifies",
            "tax advice",
            "legal advice",
            "immigration advice",
        ]

        var inspected: [String] = []
        for badge in summary.portfolioBadges {
            inspected.append(badge.title)
            inspected.append(badge.subtitle)
            inspected.append(badge.accessibilityLabel)
        }
        for badges in summary.badgesByRegion.values {
            for badge in badges {
                inspected.append(badge.title)
                inspected.append(badge.subtitle)
                inspected.append(badge.accessibilityLabel)
            }
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in recognition copy: \(copy)"
                )
            }
        }
    }
}
