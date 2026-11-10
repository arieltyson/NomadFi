// FiBotAnswerVerification.swift
// NomadFi
//
// The outcome of checking an answer's figures against the facts.

import Foundation

/// Whether every figure in an answer traces back to NomadFi's facts.
enum FiBotAnswerVerification: Sendable, Equatable {

    /// Every figure matches a cited fact, or a sum or difference of
    /// two cited figures.
    case verified

    /// The answer states no figures, so there was nothing to check.
    case noFigures

    /// These figures could not be traced to any cited fact.
    case unverified(figures: [String])

    /// Whether the answer can be shown without a caution.
    var isTrusted: Bool {
        switch self {
        case .verified, .noFigures: true
        case .unverified: false
        }
    }
}
