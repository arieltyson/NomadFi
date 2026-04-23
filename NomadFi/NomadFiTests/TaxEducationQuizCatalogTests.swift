// TaxEducationQuizCatalogTests.swift
// NomadFi
//
// Pure coverage for the Phase 7C quiz catalogue. The catalogue is
// a static namespace, so tests run in parallel without touching
// SwiftData.
//
// Pins:
//   • Every supported region ships exactly one starter quiz.
//   • Each quiz is valid under the authoring contract (3–5
//     questions, 2–4 options, exactly one correct option, unique
//     option ids, unique question ids, source lesson exists in
//     the lesson catalogue).
//   • No banned tax-advice phrasing anywhere in the quiz surface.

import Foundation
import Testing

@testable import NomadFi

struct TaxEducationQuizCatalogTests {

    // MARK: - Starter scope

    @Test("Each supported region ships one starter quiz")
    func oneQuizPerSupportedRegion() {
        for region in TaxEducationQuizCatalog.supportedRegions {
            #expect(
                TaxEducationQuizCatalog.quiz(for: region) != nil,
                "Region \(region.displayName) is missing its starter quiz."
            )
        }
    }

    @Test("Every starter quiz passes the catalogue's authoring validator")
    func everyQuizIsValid() {
        for region in TaxEducationQuizCatalog.supportedRegions {
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else {
                Issue.record("Quiz missing for \(region.displayName)")
                continue
            }
            #expect(
                TaxEducationQuizCatalog.isValid(quiz),
                "Quiz \(quiz.id) failed catalogue validation."
            )
        }
    }

    // MARK: - Question shape

    @Test("Every question has exactly one correct option that appears in its options list")
    func questionsHaveExactlyOneCorrectOption() {
        for region in TaxEducationQuizCatalog.supportedRegions {
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else { continue }
            for question in quiz.questions {
                let matching = question.options.filter { $0.id == question.correctOptionID }
                #expect(matching.count == 1, "Question \(question.id) should have exactly one correct option.")
            }
        }
    }

    @Test("Question counts and option counts stay inside the authoring bounds")
    func countsWithinAuthoringBounds() {
        for region in TaxEducationQuizCatalog.supportedRegions {
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else { continue }
            #expect((3...5).contains(quiz.questionCount))
            for question in quiz.questions {
                #expect((2...4).contains(question.options.count))
            }
        }
    }

    // MARK: - Source backing

    @Test("Every question's sourceLessonID resolves in the lesson catalogue")
    func questionsAreBackedByExistingLessons() {
        for region in TaxEducationQuizCatalog.supportedRegions {
            let lessonIDs = Set(TaxEducationCatalog.lessons(for: region).map(\.id))
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else { continue }
            for question in quiz.questions {
                #expect(
                    lessonIDs.contains(question.sourceLessonID),
                    "Question \(question.id) cites unknown lesson \(question.sourceLessonID)."
                )
            }
        }
    }

    @Test("Quiz ids and question ids are globally unique across the catalogue")
    func idsAreGloballyUnique() {
        var quizIDs = Set<String>()
        var questionIDs = Set<String>()
        for region in TaxEducationQuizCatalog.supportedRegions {
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else { continue }
            #expect(quizIDs.insert(quiz.id).inserted)
            for question in quiz.questions {
                #expect(questionIDs.insert(question.id).inserted)
            }
        }
    }

    // MARK: - Copy guard

    @Test("Quiz titles, prompts, options, and explanations never use banned tax / compliance phrasing")
    func copyGuardOnQuizVocabulary() {
        let bannedPhrases: [String] = [
            "You're done with taxes",
            "compliant",
            "you qualify",
            "you're qualified",
            "this qualifies",
            "this is deductible",
            "tax advice",
            "legal advice",
            "immigration advice",
        ]

        var inspected: [String] = []
        for region in TaxEducationQuizCatalog.supportedRegions {
            guard let quiz = TaxEducationQuizCatalog.quiz(for: region) else { continue }
            inspected.append(quiz.title)
            inspected.append(quiz.summary)
            for question in quiz.questions {
                inspected.append(question.prompt)
                inspected.append(question.explanation)
                for option in question.options {
                    inspected.append(option.text)
                }
            }
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in quiz copy: \(copy)"
                )
            }
        }
    }
}
