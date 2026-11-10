// FiBotAskError.swift
// NomadFi
//
// Why Ask FiBot could not answer.

import Foundation

/// A failure to answer, phrased for the person asking.
enum FiBotAskError: Error, Equatable, Sendable {
    /// The question and facts did not fit the on-device model.
    case tooMuchContext
    /// The system declined to answer the question.
    case declined
    /// Apple Intelligence is not available right now.
    case unavailable
    /// Anything else.
    case failed

    var message: LocalizedStringResource {
        switch self {
        case .tooMuchContext: "That needed more context than FiBot can hold. Try a narrower question."
        case .declined: "FiBot can't answer that one. Try asking about your accounts, spending or subscriptions."
        case .unavailable: "Apple Intelligence isn't available right now."
        case .failed: "FiBot couldn't finish that answer. Try again."
        }
    }
}
