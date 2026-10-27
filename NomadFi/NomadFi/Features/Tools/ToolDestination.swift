// ToolDestination.swift
// NomadFi
//
// The screen each tool opens.

import SwiftUI

/// The screen a ``Tool`` opens, pushed onto the Tools tab's stack.
struct ToolDestination: View {

    let tool: Tool

    var body: some View {
        switch tool {
        case .exchangeRates: ExchangeRatesView()
        case .subscriptions: SubscriptionsView()
        case .ledger: LedgerView()
        case .importTransactions: TransactionImportView()
        case .taxVault: TaxVaultView()
        case .investingLearn: InvestingLearnView()
        case .portfolioLab: PortfolioLabView()
        }
    }
}
