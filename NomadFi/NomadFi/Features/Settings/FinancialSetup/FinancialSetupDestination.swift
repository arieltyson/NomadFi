// FinancialSetupDestination.swift
// NomadFi
//
// The page each Financial Setup tile opens.

import SwiftUI

/// The page a ``FinancialSetupItem`` opens, pushed onto Settings' stack.
struct FinancialSetupDestination: View {

    let item: FinancialSetupItem

    var body: some View {
        switch item {
        case .accounts: AccountListView()
        case .jurisdictions: JurisdictionManagementView()
        case .creditCardCalendar: CreditCardCalendarView()
        case .financialConnections: FinancialConnectionsSettingsView()
        }
    }
}
