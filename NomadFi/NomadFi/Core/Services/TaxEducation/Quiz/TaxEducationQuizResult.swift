// TaxEducationQuizResult.swift
// NomadFi
//
// Result of a single quiz attempt. Pure value type — the scoring
// calculator returns this; the persistence layer stores the same
// numbers on the matching `TaxEducationProgressRecord`.

import Foundation

struct TaxEducationQuizResult: Sendable, Equatable {

    /// The quiz that was attempted.
    let quizID: String

    /// Region the quiz belongs to.
    let region: TaxEducationRegion

    /// Number of questions answered correctly.
    let correctCount: Int

    /// Total questions on the attempted quiz.
    let questionCount: Int

    /// Score rounded to 1 decimal place so the UI and the
    /// persistence layer always agree on the displayed number.
    let scorePercent: Double

    /// Whether the score cleared the Phase 7C pass threshold
    /// (see `TaxEducationQuizScoring.passThresholdPercent`).
    let didPass: Bool

    /// Timestamp of the attempt. The service records this into
    /// `TaxEducationProgressRecord.lastInteractedAt`.
    let attemptedAt: Date
}
