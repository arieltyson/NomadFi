// FiBotFactSheet.swift
// NomadFi
//
// Everything Ask FiBot knows, as a numbered list of facts.

import Foundation

/// The complete, numbered set of facts one question is answered from.
struct FiBotFactSheet: Sendable, Equatable {

    /// Facts in prompt order.
    let facts: [FiBotFact]

    /// Whether NomadFi holds any accounts or transactions at all.
    let hasFinancialData: Bool

    /// Looks up a fact by its citation key.
    func fact(withID id: String) -> FiBotFact? {
        facts.first { $0.id == id }
    }

    /// The facts as prompt lines, one per line.
    var promptText: String {
        facts.map(\.promptLine).joined(separator: "\n")
    }

    static let empty = FiBotFactSheet(facts: [], hasFinancialData: false)
}
