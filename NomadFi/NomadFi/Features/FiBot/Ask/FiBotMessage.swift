// FiBotMessage.swift
// NomadFi
//
// One turn in an Ask FiBot conversation.

import Foundation

/// A question, an answer or a failure, in conversation order.
struct FiBotMessage: Identifiable, Equatable, Sendable {

    enum Content: Equatable, Sendable {
        case question(String)
        case answer(FiBotAnswer)
        case failure(FiBotAskError)
    }

    let id: UUID
    let content: Content

    init(_ content: Content, id: UUID = UUID()) {
        self.id = id
        self.content = content
    }
}
