// ToolTests.swift
// NomadFi
//
// Pins the Tools tab's catalogue: its order, and that every card can
// be told apart by both symbol and colour.

import SwiftUI
import Testing

@testable import NomadFi

struct ToolTests {

    @Test("Tools appear in a stable order")
    func order() {
        #expect(Tool.allCases == [
            .exchangeRates, .subscriptions, .ledger, .importTransactions, .taxVault, .investingLearn,
        ])
    }

    @Test("Every tool has its own symbol")
    func symbolsAreUnique() {
        #expect(Set(Tool.allCases.map(\.systemImage)).count == Tool.allCases.count)
    }

    @Test("Every tool has its own colour")
    func tintsAreUnique() {
        let tints = Tool.allCases.map(\.tint)
        for (index, tint) in tints.enumerated() {
            #expect(!tints[(index + 1)...].contains(tint), "\(Tool.allCases[index]) shares its colour")
        }
    }

    @Test("Rows keep the order, two to a row, or one at accessibility sizes")
    func rows() {
        #expect(Tool.rows(columns: 2).flatMap(\.self) == Tool.allCases)
        #expect(Tool.rows(columns: 2).allSatisfy { $0.count == 2 })
        #expect(Tool.rows(columns: 1).count == Tool.allCases.count)
    }
}
