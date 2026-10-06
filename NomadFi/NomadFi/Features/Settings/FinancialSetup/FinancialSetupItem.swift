// FinancialSetupItem.swift
// NomadFi
//
// The destinations under Settings' Financial Setup section.

import SwiftUI

/// Where the person sets up their money: each a tile on Settings,
/// each opening a page of its own so long lists never lengthen
/// Settings.
enum FinancialSetupItem: String, CaseIterable, TileItem {

    case accounts
    case jurisdictions
    case creditCardCalendar
    case financialConnections

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .accounts: "Accounts"
        case .jurisdictions: "Jurisdictions"
        case .creditCardCalendar: "Credit Card Calendar"
        case .financialConnections: "Financial Connections"
        }
    }

    var systemImage: String {
        switch self {
        case .accounts: "creditcard.fill"
        case .jurisdictions: "globe.americas.fill"
        case .creditCardCalendar: "calendar"
        case .financialConnections: "link"
        }
    }

    var tint: Color {
        switch self {
        case .accounts: ColorTokens.brandPrimary
        case .jurisdictions: .blue
        case .creditCardCalendar: .orange
        case .financialConnections: .indigo
        }
    }
}
