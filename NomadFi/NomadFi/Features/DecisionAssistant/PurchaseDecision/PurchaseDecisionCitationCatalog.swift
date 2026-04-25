// PurchaseDecisionCitationCatalog.swift
// NomadFi
//
// Source-backed citations for the generic purchase engine. Phase 3
// follow-through reframed this catalog around NomadFi's actual
// cross-border purchase mission (`docs/MISSION.md`):
//
//   • Pay-in-full guidance — CFPB, regulator-grade.
//   • Credit-score basics — CFPB, regulator-grade.
//   • U.S. dispute / unauthorized-charge process — CFPB +
//     HelpWithMyBank.
//   • Canada complaint-handling process + how credit cards work —
//     FCAC.
//   • Network-level conversion / DCC framing — Visa + Mastercard
//     (network-published, never marketing).
//
// Per the evidence hierarchy in `docs/README.md`:
//   • CFPB / HelpWithMyBank / FCAC = regulator-grade, treated as
//     `.officialSource`.
//   • Visa / Mastercard pages = network-published, treated as
//     `.officialSource` (the network is the authoritative publisher
//     for its own conversion mechanics).
//
// The previous myFICO entries were moved out — credit-score / FICO
// ranking belongs to the Credit Timing engine, not the cross-border
// purchase engine.

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
            id: "cfpb_dispute_charge_purchase",
            title: "How do I dispute a charge on my credit card bill?",
            publisher: "CFPB",
            url: URL(string: "https://www.consumerfinance.gov/ask-cfpb/how-do-i-dispute-a-charge-on-my-credit-card-bill-en-61/")!,
            summary: "CFPB: U.S. cardholders can dispute billing errors and unauthorized charges through their issuer; the regulator publishes the procedural steps and timing requirements.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "helpwithmybank_disputes_purchase",
            title: "Disputes & unauthorized charges",
            publisher: "HelpWithMyBank",
            url: URL(string: "https://helpwithmybank.gov/help-topics/credit-cards/disputes-unauthorized-charges/index-disputes-unauthorized-charges.html")!,
            summary: "HelpWithMyBank (Office of the Comptroller of the Currency): plain-language reference for U.S. credit-card disputes, billing-error rights, and what to expect from the bank.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "fcac_complaint_handling_purchase",
            title: "Handle a complaint about a financial product",
            publisher: "FCAC",
            url: URL(string: "https://www.canada.ca/en/financial-consumer-agency/services/complaints/handle-complaint.html")!,
            summary: "FCAC (Financial Consumer Agency of Canada): the official Canadian complaint-handling process, including escalation steps from the institution to FCAC.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "fcac_credit_card_basics_purchase",
            title: "How credit cards work",
            publisher: "FCAC",
            url: URL(string: "https://www.canada.ca/en/financial-consumer-agency/services/credit-cards/credit-card-work.html")!,
            summary: "FCAC: how Canadian credit cards work — interest, fees, foreign-currency conversion, and the cardholder's responsibilities.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "visa_dcc_purchase",
            title: "Dynamic Currency Conversion explained",
            publisher: "Visa",
            url: URL(string: "https://usa.visa.com/travel-with-visa/dynamic-currency-conversion.html")!,
            summary: "Visa: explains Dynamic Currency Conversion at the merchant, the choice cardholders are entitled to make, and why the merchant-quoted rate may differ from Visa's network rate.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "visa_exchange_rate_purchase",
            title: "Visa exchange rate calculator",
            publisher: "Visa",
            url: URL(string: "https://usa.visa.com/support/consumer/travel-support/exchange-rate-calculator.html")!,
            summary: "Visa: the network's own exchange-rate reference for cross-currency Visa transactions. Use this to verify the assumed conversion before committing.",
            evidence: .officialSource
        ),
        ScenarioCitation(
            id: "mastercard_currency_converter_purchase",
            title: "Mastercard currency converter",
            publisher: "Mastercard",
            url: URL(string: "https://www.mastercard.com/content/mastercardcom/global/en/personal/get-support/convert-currency.html")!,
            summary: "Mastercard: the network's own currency converter for cross-currency Mastercard transactions. Use this to verify the assumed conversion before committing.",
            evidence: .officialSource
        ),
    ]
}
