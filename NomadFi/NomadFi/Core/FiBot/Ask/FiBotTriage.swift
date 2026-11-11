// FiBotTriage.swift
// NomadFi
//
// Replies FiBot can give without asking the model.

import Foundation

/// Handles the messages a language model handles badly: ones too short
/// to mean anything, and questions asked before NomadFi holds any data.
///
/// Sending "Bh" to the model with a sheet of facts made it recite a fact
/// back as though it were an answer. These cases get a plain, useful
/// reply instead, with no figures and so no "checked" badge.
enum FiBotTriage {

    /// The fewest letters or digits a message needs to be a question.
    static let minimumMeaningfulCharacters = 3

    /// A direct reply, or `nil` when the question should go to the model.
    static func reply(to question: String, sheet: FiBotFactSheet) -> FiBotAnswer? {
        let meaningful = question.unicodeScalars.count { CharacterSet.alphanumerics.contains($0) }
        if meaningful < minimumMeaningfulCharacters {
            return plain(String(localized: "I didn't catch that. Try asking something like \"How much have I spent this month?\""))
        }
        if !sheet.hasFinancialData {
            return plain(String(localized: "I can't see any of your accounts yet. Connect a bank or add an account in Settings, then ask me again."))
        }
        return nil
    }

    private static func plain(_ text: String) -> FiBotAnswer {
        FiBotAnswer(text: text, sources: [], verification: .noFigures)
    }
}
