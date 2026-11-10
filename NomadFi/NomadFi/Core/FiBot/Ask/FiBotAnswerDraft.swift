// FiBotAnswerDraft.swift
// NomadFi
//
// What the language model proposes, before NomadFi checks it.

import Foundation

/// An unverified answer: prose plus the facts the model says it used.
struct FiBotAnswerDraft: Sendable, Equatable {

    /// The answer text, in plain sentences.
    let text: String

    /// Citation keys of the facts the answer relies on.
    let citedFactIDs: [String]
}
