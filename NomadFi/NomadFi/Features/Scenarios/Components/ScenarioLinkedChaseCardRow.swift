// ScenarioLinkedChaseCardRow.swift
// NomadFi
//
// Row shown inside the Scenario brief's Chase section that lets the
// user select which saved credit-card account is their Chase Freedom
// Rise. The source of truth for the statement calendar is that
// account — edits happen in Settings → Credit Card Calendar.

import SwiftData
import SwiftUI

/// A labelled `Picker` binding the scenario's linked Chase account to
/// one of the user's saved `.creditCard` accounts (or "None").
struct ScenarioLinkedChaseCardRow: View {

    let creditCardAccounts: [Account]
    @Binding var selectedAccount: Account?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Picker("Linked card", selection: $selectedAccount) {
                Text("None")
                    .tag(Account?.none)

                ForEach(sortedAccounts, id: \.persistentModelID) { account in
                    ScenarioLinkedChaseCardPickerLabel(account: account)
                        .tag(Optional(account))
                }
            }
            .accessibilityHint(
                "Select which saved credit-card account is your Chase Freedom Rise."
            )

            if creditCardAccounts.isEmpty {
                Text(
                    "No credit-card accounts yet. Add one in Settings → Accounts to link it here."
                )
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(
                    "The statement calendar comes from the linked card's Settings entry — there is no separate date editor here."
                )
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sortedAccounts: [Account] {
        creditCardAccounts.sorted { lhs, rhs in
            if lhs.institutionName == rhs.institutionName {
                return lhs.name < rhs.name
            }
            return lhs.institutionName < rhs.institutionName
        }
    }
}

/// Single row rendered inside the picker's menu — pulls the account
/// name and institution onto two lines so the menu stays scannable.
struct ScenarioLinkedChaseCardPickerLabel: View {

    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(account.name)
            Text(account.institutionName)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }
}
