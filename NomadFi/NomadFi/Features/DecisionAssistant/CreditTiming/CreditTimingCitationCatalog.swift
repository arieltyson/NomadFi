// CreditTimingCitationCatalog.swift
// NomadFi
//
// Source-backed citations for the Credit Timing engine. Every entry
// is an **Official source** the user can open to verify the
// underlying claim — NomadFi never fetches, caches, or re-publishes
// the linked content.
//
// Deliberately anchored to regulator-grade sources (CFPB) plus the
// scoring authority's own explainer (myFICO). The engine's copy
// echoes these sources and avoids any claim they do not support.

import Foundation

/// Static citation catalog for the Credit Timing decision brief.
enum CreditTimingCitationCatalog {

    /// Sources cited on the Credit Timing brief's Sources section.
    static let creditTiming: [ScenarioCitation] = [
        ScenarioCitation(
            id: "cfpb_credit_score_basics",
            title: "What is a credit score?",
            publisher: "CFPB",
            url: URL(string: "https://www.consumerfinance.gov/ask-cfpb/what-is-a-credit-score-en-315/")!,
            summary: "Consumer Financial Protection Bureau explainer — scores reflect payment history, credit use, age of accounts, and other factors. No single step guarantees a specific score outcome.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "cfpb_pay_in_full",
            title: "Should I pay my credit card bill in full?",
            publisher: "CFPB",
            url: URL(string: "https://www.consumerfinance.gov/ask-cfpb/should-i-pay-my-credit-card-bill-in-full-en-1725/")!,
            summary: "CFPB: paying the statement balance in full by the due date generally avoids interest on new purchases. You do not need to carry a balance to build credit.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "myfico_amounts_owed",
            title: "Amounts Owed — FICO Score factors",
            publisher: "myFICO",
            url: URL(string: "https://www.myfico.com/credit-education/whats-in-your-credit-score")!,
            summary: "myFICO: Amounts Owed (including credit utilization) is roughly 30% of a FICO Score. Lower utilization is generally better; there is no single cliff value.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "myfico_reported_balance",
            title: "How credit card balances are reported to the bureaus",
            publisher: "myFICO",
            url: URL(string: "https://www.myfico.com/credit-education/blog/credit-card-reporting")!,
            summary: "myFICO blog: issuers typically report the statement balance. Paying before the statement closes is how cardholders influence the balance that shows up on the credit report.",
            evidence: .officialSource
        ),
    ]
}
