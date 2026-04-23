// TaxEducationRegionProgressSummary.swift
// NomadFi
//
// Per-region progress rollup. Derived from the catalogue bundle +
// persisted `TaxEducationProgressRecord`s by
// `TaxEducationProgressService.summary(for:in:)`.
//
// Never implies tax or compliance completion — progress here is
// about whether the user *reviewed* the education content NomadFi
// carries, not whether their return is done.
//
// Phase 7C added the quiz fields; when the region has a quiz, it
// counts as one additional step and contributes to `isReviewed`
// only when the user has passed it.

import Foundation

struct TaxEducationRegionProgressSummary: Sendable, Equatable {

    let region: TaxEducationRegion

    /// Number of lessons the user has marked reviewed.
    let lessonsReviewed: Int

    /// Total number of lessons the catalogue exposes for this
    /// region (already validated by `TaxEducationCatalog.isValid`).
    let lessonsTotal: Int

    /// Checklist items the user has toggled completed.
    let checklistItemsCompleted: Int

    /// Total items on the region's starter checklist.
    let checklistItemsTotal: Int

    /// `true` when the quiz catalogue ships a knowledge-check for
    /// this region. `false` hides the quiz step entirely from the
    /// counts below.
    let hasQuiz: Bool

    /// Latest persisted quiz status. `.notStarted` when the user
    /// hasn't attempted, `.inProgress` after a failing attempt,
    /// `.completed` only after a passing attempt.
    let quizStatus: TaxEducationProgressStatus

    /// Latest attempt's score, when one exists. `nil` when the
    /// user has never attempted the quiz.
    let quizScorePercent: Double?

    /// Number of questions on the quiz's latest attempt.
    let quizQuestionCount: Int?

    /// Correct-answer count on the latest attempt.
    let quizCorrectCount: Int?

    // MARK: - Derived

    /// `true` only when the quiz status is `.completed`.
    var quizPassed: Bool {
        quizStatus == .completed
    }

    /// `true` when the user has attempted the quiz but has not yet
    /// passed.
    var quizAttemptedNotPassed: Bool {
        quizScorePercent != nil && quizStatus != .completed
    }

    /// Quiz counts as one step when present; otherwise zero.
    private var quizStepTotal: Int {
        hasQuiz ? 1 : 0
    }
    private var quizStepReviewed: Int {
        (hasQuiz && quizPassed) ? 1 : 0
    }

    /// Combined completed-vs-total across lessons, checklist, and
    /// the knowledge-check quiz when present.
    var stepsReviewed: Int { lessonsReviewed + checklistItemsCompleted + quizStepReviewed }
    var stepsTotal: Int { lessonsTotal + checklistItemsTotal + quizStepTotal }

    /// 0.0–1.0 — returns 0 when there are no items (avoids NaN).
    var completionFraction: Double {
        guard stepsTotal > 0 else { return 0 }
        return Double(stepsReviewed) / Double(stepsTotal)
    }

    /// 0–100. Matches `completionFraction` but pre-rounded so the
    /// UI can render without another conversion pass.
    var completionPercent: Int {
        Int((completionFraction * 100).rounded())
    }

    /// True when every lesson, every checklist item, and the quiz
    /// (when present) is marked completed. Never claims the user
    /// is finished with taxes — only that they reviewed NomadFi's
    /// education content.
    var isReviewed: Bool {
        stepsTotal > 0 && stepsReviewed == stepsTotal
    }

    /// True when every checklist item and every lesson has been
    /// reviewed. The quiz unlock rule keys off this flag.
    var hasCompletedLessonsAndChecklist: Bool {
        lessonsTotal > 0
            && checklistItemsTotal > 0
            && lessonsReviewed == lessonsTotal
            && checklistItemsCompleted == checklistItemsTotal
    }

    /// Short, calm caption used in the region header.
    var displayCaption: String {
        guard stepsTotal > 0 else { return "No lessons or checklist items yet." }
        if isReviewed {
            return "All \(stepsTotal) steps reviewed for this jurisdiction."
        }
        return "\(stepsReviewed) of \(stepsTotal) steps reviewed."
    }
}
