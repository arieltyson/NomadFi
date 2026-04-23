// TaxEducationQuizSessionViewModel.swift
// NomadFi
//
// Observable state for a single quiz attempt inside the
// knowledge-check sheet. Ephemeral — instantiated per sheet
// presentation, thrown away on dismiss. Persistence only kicks
// in when `submit(...)` routes through `TaxEducationProgressService`.

import Foundation
import SwiftData
import SwiftUI

/// State holder for a single quiz attempt.
@MainActor
@Observable
final class TaxEducationQuizSessionViewModel {

    // MARK: - State

    /// Question id → selected option id. Missing keys read as
    /// "no answer yet".
    var selections: [String: String] = [:]

    /// Latest scored attempt. `nil` until the user taps Submit.
    var latestResult: TaxEducationQuizResult?

    /// Whether the user is currently viewing the results section.
    var isShowingResults: Bool {
        latestResult != nil
    }

    // MARK: - Selection

    /// Records the user's choice for a given question. Replaces
    /// any previous selection.
    func select(
        option optionID: String,
        for question: TaxEducationQuizQuestion
    ) {
        selections[question.id] = optionID
    }

    /// Returns the currently-selected option id for a question,
    /// or `nil` when the user hasn't answered yet.
    func selection(for question: TaxEducationQuizQuestion) -> String? {
        selections[question.id]
    }

    // MARK: - Submit + retake

    /// `true` when the user has chosen an option for every
    /// question — the Submit button gates on this.
    func canSubmit(_ quiz: TaxEducationQuiz) -> Bool {
        quiz.questions.allSatisfy { selections[$0.id] != nil }
    }

    /// Scores `quiz` and persists the attempt. Returns the
    /// `TaxEducationQuizResult` so the caller can surface it.
    @discardableResult
    func submit(
        quiz: TaxEducationQuiz,
        in modelContext: ModelContext,
        records: [TaxEducationProgressRecord],
        now: Date = .now
    ) -> TaxEducationQuizResult {
        let result = TaxEducationQuizScoring.score(
            quiz: quiz,
            selections: selections,
            now: now
        )
        TaxEducationProgressService.recordQuizAttempt(
            result,
            in: modelContext,
            existing: records
        )
        latestResult = result
        return result
    }

    /// Resets selections + result so the user can retake.
    func retake() {
        selections = [:]
        latestResult = nil
    }
}
