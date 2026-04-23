// TaxEducationQuizScoring.swift
// NomadFi
//
// Pure scoring helpers. Deterministic — same input, same
// `TaxEducationQuizResult`. The pass threshold is pinned here and
// referenced by both the persistence service and the focused
// tests so the number never drifts.

import Foundation

enum TaxEducationQuizScoring {

    /// Score ≥ this threshold counts as a pass. 80 % is generous
    /// enough that the quiz rewards attentive reading without
    /// letting a single guessed answer flip the result on a
    /// 3-question quiz.
    static let passThresholdPercent: Double = 80

    /// Scores `selections` against `quiz`. Missing or unknown
    /// option ids are simply not counted as correct — the scorer
    /// never throws. Result is rounded to 1 decimal.
    static func score(
        quiz: TaxEducationQuiz,
        selections: [String: String],
        now: Date = .now
    ) -> TaxEducationQuizResult {
        let correctCount = quiz.questions.reduce(0) { running, question in
            let chosen = selections[question.id]
            return chosen == question.correctOptionID ? running + 1 : running
        }
        let questionCount = quiz.questions.count
        let rawPercent = questionCount == 0
            ? 0
            : (Double(correctCount) / Double(questionCount)) * 100
        let rounded = (rawPercent * 10).rounded() / 10
        let didPass = rounded >= passThresholdPercent

        return TaxEducationQuizResult(
            quizID: quiz.id,
            region: quiz.region,
            correctCount: correctCount,
            questionCount: questionCount,
            scorePercent: rounded,
            didPass: didPass,
            attemptedAt: now
        )
    }
}
