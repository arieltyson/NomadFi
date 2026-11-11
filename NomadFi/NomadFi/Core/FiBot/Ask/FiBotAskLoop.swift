// FiBotAskLoop.swift
// NomadFi
//
// Draft, verify, correct: the closed loop behind every Ask FiBot answer.

import Foundation
import OSLog

/// Answers a question with a closed verification loop.
///
/// 1. The model drafts an answer from the fact sheet.
/// 2. ``FiBotFigureVerifier`` checks every figure against the cited facts.
/// 3. If a figure does not hold up, the model is told exactly which
///    ones and drafts again, up to ``maximumAttempts`` times.
///
/// The last draft is returned either way, carrying its verification so
/// the interface can show a caution rather than present an unchecked
/// figure as fact.
struct FiBotAskLoop: Sendable {

    /// Drafts per question, including the first.
    static let maximumAttempts = 3

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "FiBotAskLoop")

    let answerer: any FiBotAnswering

    /// Answers `question` from `sheet`.
    func answer(
        _ question: String,
        from sheet: FiBotFactSheet,
        after previousExchange: FiBotExchange? = nil
    ) async throws -> FiBotAnswer {
        if let reply = FiBotTriage.reply(to: question, sheet: sheet) { return reply }

        var correction: String?
        var result: FiBotAnswer?

        for attempt in 1...Self.maximumAttempts {
            try Task.checkCancellation()
            let draft = FiBotCitationScrubber.scrub(try await answerer.draft(
                question: question,
                sheet: sheet,
                previousExchange: previousExchange,
                correction: correction
            ))
            let (verification, sources) = FiBotFigureVerifier.verify(draft, against: sheet, question: question)
            result = FiBotAnswer(text: draft.text, sources: sources, verification: verification)

            guard case .unverified(let figures) = verification else { break }
            Self.logger.info("Attempt \(attempt, privacy: .public) had \(figures.count, privacy: .public) unverified figures")
            correction = Self.correction(for: figures)
        }

        guard let result else { throw CancellationError() }
        return result
    }

    /// The note sent back to the model after a failed check.
    static func correction(for figures: [String]) -> String {
        """
        Your previous answer used figures that are not in the facts you cited: \
        \(figures.joined(separator: ", ")). Answer again using only figures that \
        appear in the facts, and cite every fact you use.
        """
    }
}
