// JurisdictionDetailView.swift
// NomadFi
//
// One country's page: its total, accounts and transactions.

import SwiftData
import SwiftUI

/// A country's page, pushed from its Dashboard card: the total, then
/// the accounts that make it up, then the country's transactions,
/// newest first.
///
/// Both lists are fetched by predicate, so the store does the
/// filtering and the page stays live as records change.
struct JurisdictionDetailView: View {

    let profile: JurisdictionProfile

    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]

    init(profile: JurisdictionProfile) {
        self.profile = profile
        let code = profile.countryCode
        _accounts = Query(
            filter: #Predicate<Account> { $0.jurisdiction == code },
            sort: \Account.name
        )
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.jurisdiction == code },
            sort: \Transaction.date,
            order: .reverse
        )
    }

    var body: some View {
        let summary = JurisdictionSummary(profile: profile, accounts: accounts)

        List {
            if accounts.isEmpty && transactions.isEmpty {
                // Nothing here yet: say so, rather than show a lone zero
                // that reads as a page still loading.
                Section {
                    ContentUnavailableView {
                        Label("Nothing in \(profile.countryName) Yet", systemImage: "building.columns")
                    } description: {
                        Text("Connect a bank or add an account in Settings, and it will appear here.")
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    CurrencyText(
                        amount: summary.total,
                        currencyCode: summary.currency,
                        font: TypographyTokens.amountLarge
                    )
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                }
            }

            if !accounts.isEmpty {
                Section("Accounts") {
                    ForEach(accounts) { account in
                        AccountSummaryRow(account: account)
                    }
                }
            }

            if !transactions.isEmpty {
                Section("Transactions") {
                    ForEach(transactions) { transaction in
                        NavigationLink(value: transaction) {
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(String.flagEmoji(for: profile.countryCode)) \(profile.countryName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Transaction.self) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }
}
