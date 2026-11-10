// FiBotAnswer.swift
// NomadFi
//
// A checked answer, ready to show.

import Foundation

/// An answer after the closed verification loop: its text, the facts
/// it cites and whether its figures held up.
struct FiBotAnswer: Sendable, Equatable {

    /// The answer text.
    let text: String

    /// The facts the answer cites, in sheet order.
    let sources: [FiBotFact]

    /// How the figures fared against those facts.
    let verification: FiBotAnswerVerification
}
