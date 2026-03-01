// NomadFiTips.swift
// NomadFi
//
// TipKit tips for progressive feature discovery across the app.
// Each tip surfaces at the right moment to teach users about
// NomadFi's cross-border financial intelligence.

import SwiftUI
import TipKit

// MARK: - Exchange Rate Tip

/// Encourages users to explore the exchange rate ticker on the dashboard.
struct ExchangeRateTip: Tip {

    var title: Text {
        Text("Live Exchange Rates")
    }

    var message: Text? {
        Text("Tap a rate pair to see a 7-day trend. Pull down to refresh with the latest mid-market rates.")
    }

    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }
}

// MARK: - Active Card Tip

/// Explains the location-aware Active Card recommendation feature.
struct ActiveCardTip: Tip {

    var title: Text {
        Text("Active Card Recommendation")
    }

    var message: Text? {
        Text("NomadFi detects your location and recommends the card with the lowest foreign transaction fees.")
    }

    var image: Image? {
        Image(systemName: "creditcard.fill")
    }
}

// MARK: - Real Cost Tip

/// Explains the Real Cost analysis on cross-border transaction details.
struct RealCostTip: Tip {

    var title: Text {
        Text("Real Cost Analysis")
    }

    var message: Text? {
        Text("For cross-border transactions, NomadFi compares your actual exchange rate against the mid-market rate to reveal hidden FX fees.")
    }

    var image: Image? {
        Image(systemName: "arrow.triangle.swap")
    }
}

// MARK: - Subscription Arbitrage Tip

/// Explains subscription price comparison across jurisdictions.
struct SubscriptionArbitrageTip: Tip {

    var title: Text {
        Text("Subscription Arbitrage")
    }

    var message: Text? {
        Text("NomadFi compares subscription prices across your jurisdictions. Keep your cheapest subscription active and save money every month.")
    }

    var image: Image? {
        Image(systemName: "arrow.2.squarepath")
    }
}

// MARK: - Add More Accounts Tip

/// Encourages users with fewer than 3 accounts to add more for better insights.
struct AddMoreAccountsTip: Tip {

    @Parameter
    static var accountCount: Int = 0

    var title: Text {
        Text("Add More Accounts")
    }

    var message: Text? {
        Text("The more accounts you connect, the better NomadFi can optimize your cross-border finances and detect hidden fees.")
    }

    var image: Image? {
        Image(systemName: "plus.circle")
    }

    var rules: [Rule] {
        #Rule(Self.$accountCount) {
            $0 < 3
        }
    }
}

// MARK: - Tax Export Tip

/// Explains the Tax Vault export feature for NRA tax filing.
struct TaxExportTip: Tip {

    var title: Text {
        Text("Export for Tax Season")
    }

    var message: Text? {
        Text("When tax season arrives, export a structured report organized by jurisdiction. Compatible with Sprintax and TurboTax for NRA filing.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
}
