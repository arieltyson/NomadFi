// TaxEducationQuizCatalog.swift
// NomadFi
//
// Locally-authored starter quizzes — one per supported region.
// Every question is sourced from a lesson that already ships in
// `TaxEducationCatalog` via the `sourceLessonID` field. No new
// official sources are referenced here; the lesson already cites
// them and the quiz defers to that catalogue.
//
// Authoring rules (pinned by `TaxEducationQuizCatalogTests`):
//   • 3 – 5 questions per quiz.
//   • 2 – 4 options per question.
//   • Exactly one `correctOptionID` that appears in `options`.
//   • Every `sourceLessonID` resolves in `TaxEducationCatalog`.
//   • Question ids are unique within a quiz; quiz ids are unique
//     globally so the progress record lookup is deterministic.
//   • No professional-judgment phrasing in prompts or
//     explanations — see `copyGuardOnQuizVocabulary()` in the
//     focused tests for the banned list.

import Foundation

enum TaxEducationQuizCatalog {

    // MARK: - Public API

    /// Returns the starter quiz for a region, or `nil` when the
    /// region has no quiz yet (Phase 7C ships one per region).
    static func quiz(for region: TaxEducationRegion) -> TaxEducationQuiz? {
        switch region {
        case .unitedStates: unitedStatesQuiz
        case .canada: canadaQuiz
        case .trinidadAndTobago: trinidadAndTobagoQuiz
        }
    }

    /// Every region the quiz catalogue covers today.
    static var supportedRegions: [TaxEducationRegion] {
        TaxEducationRegion.allCases
    }

    // MARK: - Validation

    /// Returns `true` when `quiz` satisfies the authoring
    /// contract: bounded question/option counts, a correct option
    /// that lives in the option list, unique question ids, and a
    /// `sourceLessonID` that resolves in the lesson catalogue.
    static func isValid(_ quiz: TaxEducationQuiz) -> Bool {
        guard !quiz.id.isEmpty,
              !quiz.title.isEmpty,
              !quiz.summary.isEmpty,
              (3...5).contains(quiz.questionCount)
        else { return false }

        var questionIDs = Set<String>()
        let lessonIDs = Set(
            TaxEducationCatalog
                .lessons(for: quiz.region)
                .map(\.id)
        )

        for question in quiz.questions {
            guard !question.id.isEmpty,
                  !question.prompt.isEmpty,
                  !question.explanation.isEmpty,
                  (2...4).contains(question.options.count),
                  questionIDs.insert(question.id).inserted,
                  lessonIDs.contains(question.sourceLessonID)
            else { return false }

            let optionIDs = Set(question.options.map(\.id))
            guard optionIDs.count == question.options.count else { return false }
            guard optionIDs.contains(question.correctOptionID) else { return false }
        }
        return true
    }

    // MARK: - United States

    private static let unitedStatesQuiz = TaxEducationQuiz(
        id: "us-knowledge-check",
        region: .unitedStates,
        title: "United States knowledge check",
        summary: "Three short questions based on the U.S. lessons above.",
        questions: [
            TaxEducationQuizQuestion(
                id: "us-q-pub-519",
                prompt: "Which IRS publication walks through the tests used to determine resident vs. nonresident status for U.S. tax purposes?",
                options: [
                    TaxEducationQuizOption(id: "us-q-pub-519-a", text: "Publication 17"),
                    TaxEducationQuizOption(id: "us-q-pub-519-b", text: "Publication 519"),
                    TaxEducationQuizOption(id: "us-q-pub-519-c", text: "Publication 54"),
                ],
                correctOptionID: "us-q-pub-519-b",
                explanation: "Publication 519 is the IRS's U.S. Tax Guide for Aliens and the main reference the lesson above points to.",
                sourceLessonID: "us-resident-vs-nonresident"
            ),
            TaxEducationQuizQuestion(
                id: "us-q-form-8843",
                prompt: "Which form may some F, J, M, or Q visa holders file to explain their days of presence as exempt individuals?",
                options: [
                    TaxEducationQuizOption(id: "us-q-form-8843-a", text: "Form 1040"),
                    TaxEducationQuizOption(id: "us-q-form-8843-b", text: "Form 1040-NR only"),
                    TaxEducationQuizOption(id: "us-q-form-8843-c", text: "Form 8843"),
                ],
                correctOptionID: "us-q-form-8843-c",
                explanation: "Form 8843 is the statement for exempt individuals that the IRS foreign-students hub links to.",
                sourceLessonID: "us-j1-student-reminders"
            ),
            TaxEducationQuizQuestion(
                id: "us-q-1040nr",
                prompt: "Which form is the U.S. individual return many nonresident filers use?",
                options: [
                    TaxEducationQuizOption(id: "us-q-1040nr-a", text: "Form 1040"),
                    TaxEducationQuizOption(id: "us-q-1040nr-b", text: "Form 1040-NR"),
                    TaxEducationQuizOption(id: "us-q-1040nr-c", text: "Form 1040-ES"),
                ],
                correctOptionID: "us-q-1040nr-b",
                explanation: "Form 1040-NR is the nonresident individual return the lesson above references.",
                sourceLessonID: "us-1040nr-basics"
            ),
        ]
    )

    // MARK: - Canada

    private static let canadaQuiz = TaxEducationQuiz(
        id: "ca-knowledge-check",
        region: .canada,
        title: "Canada knowledge check",
        summary: "Three short questions based on the Canada lessons above.",
        questions: [
            TaxEducationQuizQuestion(
                id: "ca-q-residency",
                prompt: "CRA determines Canadian tax residency primarily by weighing which of the following?",
                options: [
                    TaxEducationQuizOption(id: "ca-q-residency-a", text: "Citizenship only"),
                    TaxEducationQuizOption(id: "ca-q-residency-b", text: "Factual ties to Canada (dwelling, spouse, dependents, length of stay)"),
                    TaxEducationQuizOption(id: "ca-q-residency-c", text: "Whether the person owns a vehicle in Canada"),
                ],
                correctOptionID: "ca-q-residency-b",
                explanation: "CRA's residency-determination page walks through factual ties rather than citizenship alone.",
                sourceLessonID: "ca-residency-basics"
            ),
            TaxEducationQuizQuestion(
                id: "ca-q-student-slip",
                prompt: "Which slip do Canadian post-secondary institutions typically issue to report tuition paid?",
                options: [
                    TaxEducationQuizOption(id: "ca-q-student-slip-a", text: "T4"),
                    TaxEducationQuizOption(id: "ca-q-student-slip-b", text: "T2202"),
                    TaxEducationQuizOption(id: "ca-q-student-slip-c", text: "T5"),
                ],
                correctOptionID: "ca-q-student-slip-b",
                explanation: "The T2202 is the tuition-and-enrolment certificate the CRA student page references.",
                sourceLessonID: "ca-international-students"
            ),
            TaxEducationQuizQuestion(
                id: "ca-q-contribution-room",
                prompt: "Where does CRA publish your personal TFSA and RRSP contribution room?",
                options: [
                    TaxEducationQuizOption(id: "ca-q-contribution-room-a", text: "The issuing bank's statement"),
                    TaxEducationQuizOption(id: "ca-q-contribution-room-b", text: "CRA My Account"),
                    TaxEducationQuizOption(id: "ca-q-contribution-room-c", text: "Inside NomadFi"),
                ],
                correctOptionID: "ca-q-contribution-room-b",
                explanation: "The TFSA/RRSP lesson is explicit that NomadFi cannot read your personal room — CRA My Account is authoritative.",
                sourceLessonID: "ca-tfsa-rrsp-highlevel"
            ),
        ]
    )

    // MARK: - Trinidad and Tobago

    private static let trinidadAndTobagoQuiz = TaxEducationQuiz(
        id: "tt-knowledge-check",
        region: .trinidadAndTobago,
        title: "Trinidad and Tobago knowledge check",
        summary: "Three short questions based on the T&T lessons above.",
        questions: [
            TaxEducationQuizQuestion(
                id: "tt-q-bir",
                prompt: "Which authority administers personal income tax in Trinidad and Tobago?",
                options: [
                    TaxEducationQuizOption(id: "tt-q-bir-a", text: "Ministry of Finance only"),
                    TaxEducationQuizOption(id: "tt-q-bir-b", text: "Board of Inland Revenue (BIR)"),
                    TaxEducationQuizOption(id: "tt-q-bir-c", text: "Central Bank of Trinidad and Tobago"),
                ],
                correctOptionID: "tt-q-bir-b",
                explanation: "The Board of Inland Revenue, under the Ministry of Finance, administers personal income tax in T&T.",
                sourceLessonID: "tt-personal-tax-basics"
            ),
            TaxEducationQuizQuestion(
                id: "tt-q-fiutt",
                prompt: "Which T&T body publishes AML / CFT record-keeping expectations relevant to personal financial records?",
                options: [
                    TaxEducationQuizOption(id: "tt-q-fiutt-a", text: "FIUTT (Financial Intelligence Unit of Trinidad and Tobago)"),
                    TaxEducationQuizOption(id: "tt-q-fiutt-b", text: "Ministry of Tourism"),
                    TaxEducationQuizOption(id: "tt-q-fiutt-c", text: "Caribbean Court of Justice"),
                ],
                correctOptionID: "tt-q-fiutt-a",
                explanation: "FIUTT publishes AML / CFT expectations that the compliance-records lesson references directly.",
                sourceLessonID: "tt-compliance-records"
            ),
            TaxEducationQuizQuestion(
                id: "tt-q-records",
                prompt: "Why does the compliance-records lesson suggest storing cross-border transaction records alongside local ones?",
                options: [
                    TaxEducationQuizOption(id: "tt-q-records-a", text: "To make NomadFi's export button shorter"),
                    TaxEducationQuizOption(id: "tt-q-records-b", text: "To reconcile cross-border transactions later and respond to official information requests"),
                    TaxEducationQuizOption(id: "tt-q-records-c", text: "Because the Central Bank demands it from every resident"),
                ],
                correctOptionID: "tt-q-records-b",
                explanation: "Keeping orderly records is procedural preparation — it makes responding to official requests straightforward.",
                sourceLessonID: "tt-compliance-records"
            ),
        ]
    )
}
