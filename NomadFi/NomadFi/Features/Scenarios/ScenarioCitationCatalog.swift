// ScenarioCitationCatalog.swift
// NomadFi
//
// Curated source links the Scenario Decision Brief cites. Every entry
// is an **Official source** the user can open to verify the underlying
// fact themselves — the app does not fetch or cache the linked content.

import Foundation

/// Static, hand-curated citation catalogs for each scenario.
enum ScenarioCitationCatalog {

    /// Sources cited on Scenario 1's Amazon.com arrival-order brief.
    ///
    /// Ordering groups the citations by the part of the brief they
    /// support: Amazon Currency Converter, Chase Freedom Rise, Wise,
    /// and the credit-bureau reporting reference.
    static let scenario1: [ScenarioCitation] = [
        ScenarioCitation(
            id: "amazon_currency_converter",
            title: "Amazon Currency Converter — Help & Customer Service",
            publisher: "Amazon",
            // Amazon's public Help article on Amazon Currency Converter.
            url: URL(string: "https://www.amazon.com/gp/help/customer/display.html?nodeId=GDC2AGDZELDDVD4K")!,
            summary: "Official explanation that ACC locks a guaranteed exchange rate at checkout and that the displayed total includes an exchange-rate guarantee fee.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "chase_freedom_rise_product_page",
            title: "Chase Freedom Rise — product page",
            publisher: "Chase",
            url: URL(string: "https://creditcards.chase.com/cash-back-credit-cards/freedom/rise")!,
            summary: "Official Chase product page for 1.5% cash back, purchase APR, card benefits, and purchase protection terms.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "chase_credit_line_increase",
            title: "Credit line increase — Freedom Rise evaluation after six months",
            publisher: "Chase",
            url: URL(string: "https://www.chase.com/personal/credit-cards/education/build-credit/how-to-request-credit-line-increase")!,
            summary: "Chase's own explainer: Freedom Rise cardmembers may be automatically evaluated for a credit-line increase after about six months, with on-time full payments as a key factor.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "wise_card_fees",
            title: "Wise card fees — spending from a currency balance",
            publisher: "Wise",
            url: URL(string: "https://wise.com/help/articles/2977937/what-are-the-fees-for-using-my-wise-card")!,
            summary: "Wise Help Centre: spending from a held currency balance is free when the balance covers the purchase; otherwise Wise converts at its mid-market rate with a small conversion fee.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "myfico_statement_balance_reporting",
            title: "How credit card balances are reported to the credit bureaus",
            publisher: "myFICO",
            url: URL(string: "https://www.myfico.com/credit-education/blog/credit-card-reporting")!,
            summary: "Background on how issuers typically report the statement balance to the credit bureaus, which is why paying before statement close protects utilization.",
            evidence: .officialSource
        ),
    ]
}
