// TaxEducationQuiz.swift
// NomadFi
//
// A single region's starter knowledge-check quiz. Deterministic
// + locally authored, cited against the lesson catalogue that
// already ships in `TaxEducationCatalog`. No generated content,
// no new source coverage.

import Foundation

struct TaxEducationQuiz: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — the Phase 7C starter scope uses one
    /// quiz per region, but `id` stays per-quiz so future phases
    /// can ship multiple quizzes without schema changes.
    let id: String

    let region: TaxEducationRegion

    /// Short, honest title ("U.S. knowledge check"). Never
    /// "Tax quiz" or "Are you compliant?".
    let title: String

    /// Display tagline shown under the title. Two lines max.
    let summary: String

    /// 3–5 questions per the Phase 7C authoring contract.
    let questions: [TaxEducationQuizQuestion]

    // MARK: - Derived

    var questionCount: Int { questions.count }
}
