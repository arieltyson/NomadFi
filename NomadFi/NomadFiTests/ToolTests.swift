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
            .exchangeRates, .subscriptions, .ledger, .importTransactions, .taxVault, .investingLearn, .portfolioLab,
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

    @Test("Rows keep the order, two to a row with any odd tool last, or one at accessibility sizes")
    func rows() {
        let pairs = TileLayout.rows(Tool.allCases, columns: 2)
        #expect(pairs.flatMap(\.self) == Tool.allCases)
        #expect(pairs.dropLast().allSatisfy { $0.count == 2 })
        #expect(pairs.last?.count == 2 - Tool.allCases.count % 2)
        #expect(TileLayout.rows(Tool.allCases, columns: 1).count == Tool.allCases.count)
    }
}
