// Tool.swift
// NomadFi
//
// The manual tools offered on the Tools tab.

import SwiftUI

/// One of NomadFi's optional manual tools, in the order the Tools tab
/// shows them.
///
/// Each tool owns a hue so the grid can be told apart at a glance;
/// every card is otherwise identical, so the hues read as one family.
/// System colours keep each one legible in dark mode and with
/// Increase Contrast, and the title never carries the colour.
enum Tool: String, CaseIterable, TileItem {

    case exchangeRates
    case subscriptions
    case ledger
    case importTransactions
    case taxVault
    case investingLearn

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .exchangeRates: "Exchange Rates"
        case .subscriptions: "Subscriptions"
        case .ledger: "Ledger"
        case .importTransactions: "Import Transactions"
        case .taxVault: "Tax Vault"
        case .investingLearn: "Investing Learn"
        }
    }

    var systemImage: String {
        switch self {
        case .exchangeRates: "dollarsign.arrow.circlepath"
        case .subscriptions: "arrow.triangle.2.circlepath.circle.fill"
        case .ledger: "list.bullet.rectangle.portrait.fill"
        case .importTransactions: "tablecells.fill"
        case .taxVault: "doc.text.viewfinder"
        case .investingLearn: "books.vertical.fill"
        }
    }

    var tint: Color {
        switch self {
        case .exchangeRates: ColorTokens.brandPrimary
        case .subscriptions: .pink
        case .ledger: .blue
        case .importTransactions: .orange
        case .taxVault: .green
        case .investingLearn: .indigo
        }
    }
}
