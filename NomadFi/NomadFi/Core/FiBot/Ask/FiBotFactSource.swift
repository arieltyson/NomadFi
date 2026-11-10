// FiBotFactSource.swift
// NomadFi
//
// Reads the user's records into a fact sheet when a question is asked.

import Foundation
import SwiftData

/// Supplies a fresh fact sheet for each question.
@MainActor
protocol FiBotFactSource {
    func currentSheet() throws -> FiBotFactSheet
}

/// Reads accounts, transactions, subscriptions and budgets from
/// SwiftData at the moment of asking, so answers reflect the latest
/// sync without keeping a live query open behind the conversation.
@MainActor
struct SwiftDataFiBotFactSource: FiBotFactSource {

    let modelContext: ModelContext

    func currentSheet() throws -> FiBotFactSheet {
        FiBotFactSheetBuilder().build(
            accounts: try modelContext.fetch(FetchDescriptor<Account>()),
            transactions: try modelContext.fetch(FetchDescriptor<Transaction>()),
            subscriptions: try modelContext.fetch(FetchDescriptor<Subscription>()),
            budgets: try modelContext.fetch(FetchDescriptor<Budget>())
        )
    }
}

/// A fixed sheet, for previews and tests.
struct StaticFiBotFactSource: FiBotFactSource {
    let sheet: FiBotFactSheet
    func currentSheet() throws -> FiBotFactSheet { sheet }
}
