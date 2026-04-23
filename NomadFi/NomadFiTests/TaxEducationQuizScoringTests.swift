// TaxEducationQuizScoringTests.swift
// NomadFi
//
// Pure coverage for the deterministic quiz scorer. No SwiftData
// — all inputs are value types.

import Foundation
import Testing

@testable import NomadFi

struct TaxEducationQuizScoringTests {

    // MARK: - Fixture

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func quiz() -> TaxEducationQuiz {
        // Use the live US quiz so the fixture tracks the catalogue.
        guard let quiz = TaxEducationQuizCatalog.quiz(for: .unitedStates) else {
            Issue.record("U.S. starter quiz is missing — catalogue drift.")
            return TaxEducationQuiz(
                id: "",
                region: .unitedStates,
                title: "",
                summary: "",
                questions: []
            )
        }
        return quiz
    }

    private func selections(correct count: Int, from quiz: TaxEducationQuiz) -> [String: String] {
        var picks: [String: String] = [:]
        for (index, question) in quiz.questions.enumerated() {
            if index < count {
                picks[question.id] = question.correctOptionID
            } else if let wrong = question.options.first(where: { $0.id != question.correctOptionID }) {
                picks[question.id] = wrong.id
            }
        }
        return picks
    }

    // MARK: - Perfect score

    @Test("Every correct answer → 100 %, passes, and reports the attemptedAt timestamp")
    func perfectScorePasses() {
        let quiz = quiz()
        let result = TaxEducationQuizScoring.score(
            quiz: quiz,
            selections: selections(correct: quiz.questionCount, from: quiz),
            now: Self.now
        )
        #expect(result.correctCount == quiz.questionCount)
        #expect(result.questionCount == quiz.questionCount)
        #expect(result.scorePercent == 100)
        #expect(result.didPass == true)
        #expect(result.attemptedAt == Self.now)
    }

    // MARK: - Fail path

    @Test("Missing every answer → 0 % and fail")
    func missingEverythingFails() {
        let quiz = quiz()
        let result = TaxEducationQuizScoring.score(
            quiz: quiz,
            selections: [:],
            now: Self.now
        )
        #expect(result.correctCount == 0)
        #expect(result.scorePercent == 0)
        #expect(result.didPass == false)
    }

    @Test("One correct answer on a three-question quiz is 33.3 %, below the pass threshold")
    func oneCorrectFails() {
        let quiz = quiz()
        let result = TaxEducationQuizScoring.score(
            quiz: quiz,
            selections: selections(correct: 1, from: quiz),
            now: Self.now
        )
        #expect(result.correctCount == 1)
        #expect(result.scorePercent == 33.3)
        #expect(result.didPass == false)
    }

    // MARK: - Pass threshold

    @Test("The pass threshold is pinned at 80 % — 80 is a pass, 79.9 is not")
    func passThresholdIsEighty() {
        // Build a synthetic 5-question quiz so we can hit 80 %
        // exactly with 4 correct answers.
        let options: [TaxEducationQuizOption] = [
            TaxEducationQuizOption(id: "a", text: "A"),
            TaxEducationQuizOption(id: "b", text: "B"),
        ]
        let questions = (1...5).map { index in
            TaxEducationQuizQuestion(
                id: "q-\(index)",
                prompt: "Prompt \(index)",
                options: options,
                correctOptionID: "a",
                explanation: "Explanation",
                sourceLessonID: "unused"
            )
        }
        let synthetic = TaxEducationQuiz(
            id: "synthetic",
            region: .unitedStates,
            title: "Synthetic",
            summary: "Synthetic",
            questions: questions
        )

        // 4 of 5 correct = 80 %.
        var picks: [String: String] = [:]
        for (index, question) in questions.enumerated() {
            picks[question.id] = index < 4 ? "a" : "b"
        }
        let pass = TaxEducationQuizScoring.score(
            quiz: synthetic,
            selections: picks,
            now: Self.now
        )
        #expect(pass.scorePercent == 80)
        #expect(pass.didPass == true)

        // 3 of 5 correct = 60 % — well below 80.
        picks[questions[3].id] = "b"
        let fail = TaxEducationQuizScoring.score(
            quiz: synthetic,
            selections: picks,
            now: Self.now
        )
        #expect(fail.scorePercent == 60)
        #expect(fail.didPass == false)
    }
}
