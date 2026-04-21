// CreditCardCalendarSection.swift
// NomadFi
//
// Settings section dedicated to credit-card statement calendars. Lives
// immediately below the Accounts section so users can move from "the
// card exists" to "these are its billing dates" without leaving
// Settings.

import SwiftUI

/// Settings section listing credit-card accounts with their statement
/// calendar state. Each row pushes a dedicated editor.
struct CreditCardCalendarSection: View {

    let accounts: [Account]

    var body: some View {
        Section {
            if creditCards.isEmpty {
                ContentUnavailableView {
                    Label("No Credit Cards Yet", systemImage: "creditcard")
                } description: {
                    Text("Add a credit-card account above to track statement close and payment due dates here.")
                }
            } else {
                ForEach(creditCards) { account in
                    NavigationLink {
                        CreditCardScheduleEditView(account: account)
                    } label: {
                        CreditCardScheduleRow(account: account)
                    }
                    .accessibilityHint("Opens the statement calendar editor for this card.")
                }
            }
        } header: {
            Text("Credit Card Calendar")
        } footer: {
            Text("Paying before statement close can reduce reported utilization, but issuer reporting can vary. Verify dates in your issuer app.")
        }
    }

    // MARK: - Filtering

    /// Only `.creditCard` accounts, sorted by institution then name.
    private var creditCards: [Account] {
        accounts
            .filter { $0.accountType == .creditCard }
            .sorted { lhs, rhs in
                if lhs.institutionName == rhs.institutionName {
                    return lhs.name < rhs.name
                }
                return lhs.institutionName < rhs.institutionName
            }
    }
}
