// FiBotAnswering.swift
// NomadFi
//
// The seam between Ask FiBot and whichever model writes answers.

import Foundation

/// Writes a draft answer to a question from a fact sheet.
///
/// The production conformer runs Apple's on-device model; tests and
/// previews use ``ScriptedFiBotAnswerer``. Implementations must stay
/// on device: the sheet holds the user's private financial data.
protocol FiBotAnswering: Sendable {

    /// Whether answers can be produced right now.
    func availability() -> FiBotAvailability

    /// Drafts an answer.
    ///
    /// - Parameters:
    ///   - question: The person's question.
    ///   - sheet: The only facts the answer may use.
    ///   - previousExchange: The last question and answer, for follow-ups.
    ///   - correction: When a previous draft failed verification, what
    ///     was wrong with it, so the model can correct itself.
    func draft(
        question: String,
        sheet: FiBotFactSheet,
        previousExchange: FiBotExchange?,
        correction: String?
    ) async throws -> FiBotAnswerDraft
}

/// A question and the answer it received.
struct FiBotExchange: Sendable, Equatable {
    let question: String
    let answer: String
}
