// PurchaseDecisionCitationCatalog.swift
// NomadFi
//
// Source-backed citations for the generic purchase engine. Every
// entry is an **Official source** the user can open to verify the
// claim themselves. NomadFi never fetches the content.
//
// Citations overlap with the Credit Timing catalog by design —
// both engines share the same regulator-grade anchors (CFPB, myFICO)
// and the purchase engine's recommendations lean on the same
// "statement balance reporting" and "pay in full" evidence.

import Foundation

/// Static citation catalog for the generic purchase decision brief.
enum PurchaseDecisionCitationCatalog {

    /// Sources shown on the generic purchase brief's Sources section.
    static let purchaseDecision: [ScenarioCitation] = [
        ScenarioCitation(
            id: "cfpb_pay_in_full_purchase",
            title: "Should I pay my credit card bill in full?",
            publisher: "CFPB",
            url: URL(string: "https://www.consumerfinance.gov/ask-cfpb/should-i-pay-my-credit-card-bill-in-full-en-1725/")!,
            summary: "CFPB: paying the statement balance in full by the due date generally avoids interest on new purchases. You do not need to carry a balance to build credit.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "cfpb_credit_score_basics_purchase",
            title: "What is a credit score?",
            publisher: "CFPB",
            url: URL(string: "https://www.consumerfinance.gov/ask-cfpb/what-is-a-credit-score-en-315/")!,
            summary: "CFPB: credit scores reflect payment history, credit use, age of accounts, and other factors. No single step guarantees a specific outcome.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "myfico_amounts_owed_purchase",
            title: "Amounts Owed — FICO Score factors",
            publisher: "myFICO",
            url: URL(string: "https://www.myfico.com/credit-education/whats-in-your-credit-score")!,
            summary: "myFICO: Amounts Owed (including credit utilization) is roughly 30% of a FICO Score. Lower utilization is generally better; there is no single cliff value.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "myfico_reported_balance_purchase",
            title: "How credit card balances are reported to the bureaus",
            publisher: "myFICO",
            url: URL(string: "https://www.myfico.com/credit-education/blog/credit-card-reporting")!,
            summary: "myFICO blog: issuers typically report the statement balance. Paying before the statement closes is how cardholders influence the balance on the credit report.",
            evidence: .officialSource
        ),
    ]
}
