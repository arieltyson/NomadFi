// ScenarioDecisionEngine.swift
// NomadFi
//
// Pure, testable decision engine behind the Scenario Decision Brief.
// Deterministic: same `ScenarioFacts` + `ScenarioDecisionState` always
// produce the same `ScenarioDecision`. No I/O, no networking, no dates.
//
// The evidence standard is defined in `docs/README.md`. Every recommendation
// here must stay honest about what is a screenshot fact, what is an
// official source, what needs user input, and what is inference.

import Foundation

/// Decides how Ariel should pay for the Scenario 1 Amazon.com arrival
/// order.
enum ScenarioDecisionEngine {

    // MARK: - Public API

    /// Produces the full decision brief for the given facts and the
    /// current user-confirmed guardrail state.
    static func decide(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> ScenarioDecision {
        let path = recommendedPath(state: state)
        let ruling = ruling(for: path)
        let rationale = rationale(facts: facts, path: path, state: state)
        let outstanding = outstandingChecks(state: state, path: path)
        let options = paymentOptions(facts: facts, state: state)

        return ScenarioDecision(
            ruling: ruling,
            primaryPath: path,
            rationale: rationale,
            outstandingChecks: outstanding,
            paymentOptions: options,
            costBreakdown: costBreakdown(facts: facts),
            hardRules: hardRules,
            beforeCheckoutChecklist: beforeCheckoutChecklist
        )
    }

    // MARK: - Path selection

    /// The ordering here is deliberate:
    ///
    /// 1. Cart comes first. A cheaper card on a bloated cart saves nothing.
    /// 2. Chase Freedom Rise is only recommended when **both** utilization
    ///    guardrails are explicitly confirmed by the user.
    /// 3. Wise USD is the safe fallback — but only when the user has
    ///    confirmed their USD balance.
    /// 4. Otherwise the engine refuses to pick, because it would be
    ///    guessing on someone else's money.
    static func recommendedPath(
        state: ScenarioDecisionState
    ) -> ScenarioRecommendedPath {
        guard state.cartShippingReviewed else {
            return .reviewCartFirst
        }

        if state.chaseAvailableCreditConfirmed && state.canPayBeforeStatementClose {
            return .chaseFreedomRiseUSD
        }

        if state.wiseBalanceSufficient {
            return .wiseUSD
        }

        return .awaitingUserInput
    }

    // MARK: - Payment option matrix

    static func paymentOptions(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> [ScenarioPaymentOption] {
        [
            chaseOption(facts: facts, state: state),
            wiseOption(facts: facts, state: state),
            amexUSDOption(facts: facts),
            amexCobaltACCOption(facts: facts),
        ]
    }

    // MARK: - Hard rules

    static let hardRules: [String] = [
        "Never carry a Chase balance at the current purchase APR just to earn rewards.",
        "Never present rewards, FX, or eligibility as verified before the official source check.",
        "Never enable Amazon Currency Converter without comparing its embedded fee against the issuer's verified foreign-currency commission.",
    ]

    // MARK: - Before-checkout checklist

    static let beforeCheckoutChecklist: [ScenarioChecklistItem] = [
        ScenarioChecklistItem(
            id: "cart_shipping_reviewed",
            title: "Reviewed cart for paid or overnight shipping lines and accidental Subscribe & Save",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "chase_available_credit_confirmed",
            title: "Confirmed Chase Freedom Rise available credit comfortably exceeds the USD checkout amount",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "can_pay_before_statement_close",
            title: "Will pay the Chase balance before the next statement closes (no balance carried, no interest)",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "wise_balance_sufficient",
            title: "Wise USD balance is sufficient to cover the USD checkout amount",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "airbnb_package_receipt_confirmed",
            title: "Airbnb host confirmed package receipt, or delivery is timed for on-or-after arrival",
            evidence: .needsUserInput
        ),
    ]
}

// MARK: - Private helpers

private extension ScenarioDecisionEngine {

    static func ruling(for path: ScenarioRecommendedPath) -> String {
        switch path {
        case .reviewCartFirst:
            return "Review the cart first. Remove paid / overnight shipping and any accidental Subscribe & Save, then revisit payment."
        case .chaseFreedomRiseUSD:
            return "Pay in USD with Chase Freedom Rise — utilization guardrails confirmed. Pay before statement close."
        case .wiseUSD:
            return "Pay in USD with Wise USD — cleanest FX path while Chase utilization is protected."
        case .awaitingUserInput:
            return "Pay in USD. Use Chase only if utilization is controlled; otherwise use Wise USD."
        }
    }

    static func rationale(
        facts: ScenarioFacts,
        path: ScenarioRecommendedPath,
        state: ScenarioDecisionState
    ) -> [String] {
        var lines: [String] = []

        let feePercent = facts.accFeePercentOfPreFeeCAD * 100
        let effectiveRate = facts.accEffectiveRateCADperUSD
        lines.append(
            "Amazon Currency Converter adds CAD \(formatted(facts.accExplicitFeeCAD, fractionDigits: 2)) ≈ \(formatted(feePercent, fractionDigits: 2))% over Amazon's displayed CAD conversion — effective rate ≈ \(formatted(effectiveRate, fractionDigits: 4)) CAD/USD vs. displayed \(formatted(facts.amazonDisplayedRateCADperUSD, fractionDigits: 5))."
        )

        if let utilAtZero = facts.chaseUtilizationPercent(currentBalanceUSD: 0) {
            lines.append(
                "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) is ≈ \(formatted(utilAtZero * 100, fractionDigits: 1))% of the Chase Freedom Rise USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)) total limit (assuming a zero current balance — the real value needs user confirmation)."
            )
        }

        switch path {
        case .reviewCartFirst:
            lines.append("Cart optimization has not been confirmed. Fix shipping before picking a card.")
        case .chaseFreedomRiseUSD:
            lines.append("Chase available credit and ability to pay before statement close are both confirmed, so the utilization risk from a ~68.5% line-at-zero utilization window is mitigated.")
        case .wiseUSD:
            if !state.chaseAvailableCreditConfirmed || !state.canPayBeforeStatementClose {
                lines.append("Chase utilization guardrails are not confirmed, so Wise USD is the safer operational path — it avoids reporting high Chase utilization to the bureaus entirely.")
            }
        case .awaitingUserInput:
            lines.append("Not enough user-confirmed guardrails to pick between Chase and Wise. The ruling is a stance, not a selection.")
        }

        return lines
    }

    static func outstandingChecks(
        state: ScenarioDecisionState,
        path: ScenarioRecommendedPath
    ) -> [String] {
        var checks: [String] = []
        if !state.cartShippingReviewed {
            checks.append("Review the cart for paid / overnight shipping and accidental Subscribe & Save.")
        }
        if !state.chaseAvailableCreditConfirmed {
            checks.append("Confirm Chase Freedom Rise available credit and current statement balance in the Chase app.")
        }
        if !state.canPayBeforeStatementClose {
            checks.append("Commit to paying the Chase balance before the next statement closes.")
        }
        if !state.wiseBalanceSufficient {
            checks.append("Check the USD balance in Wise.")
        }
        if !state.airbnbPackageReceiptConfirmed {
            checks.append("Confirm Airbnb host will accept packages, or time delivery for on-or-after arrival.")
        }
        // Cross-cutting verification the user cannot clear by toggling:
        checks.append("Verify Amex Canada Cobalt's current foreign-currency conversion commission on the official Cardmember Agreement before treating Amex USD as a real candidate.")
        checks.append("Verify Chase Freedom Rise's 1.5% cash-back eligibility on Amazon.com against the official Chase product page before counting it as a benefit.")

        // Dedup while preserving order.
        var seen = Set<String>()
        return checks.filter { seen.insert($0).inserted }
    }

    static func costBreakdown(facts: ScenarioFacts) -> [ScenarioCostLine] {
        let feePercent = facts.accFeePercentOfPreFeeCAD * 100
        return [
            ScenarioCostLine(
                id: "usd_checkout",
                label: "USD checkout",
                value: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2))",
                evidence: .screenshotFact,
                note: nil
            ),
            ScenarioCostLine(
                id: "acc_cad_total",
                label: "Amazon Currency Converter (CAD)",
                value: "CAD \(formatted(facts.accCadTotal, fractionDigits: 2))",
                evidence: .screenshotFact,
                note: nil
            ),
            ScenarioCostLine(
                id: "amazon_rate",
                label: "Amazon displayed rate",
                value: "1 USD = \(formatted(facts.amazonDisplayedRateCADperUSD, fractionDigits: 5)) CAD",
                evidence: .screenshotFact,
                note: nil
            ),
            ScenarioCostLine(
                id: "acc_fee",
                label: "ACC exchange-rate guarantee fee",
                value: "CAD \(formatted(facts.accExplicitFeeCAD, fractionDigits: 2)) ≈ \(formatted(feePercent, fractionDigits: 2))% of pre-fee CAD",
                evidence: .inference,
                note: "Computed as CAD fee ÷ (USD × Amazon's displayed CAD rate)."
            ),
            ScenarioCostLine(
                id: "acc_effective_rate",
                label: "ACC effective all-in rate",
                value: "≈ \(formatted(facts.accEffectiveRateCADperUSD, fractionDigits: 4)) CAD/USD",
                evidence: .inference,
                note: "CAD total ÷ USD checkout."
            ),
            ScenarioCostLine(
                id: "chase_utilization_at_zero",
                label: "Chase utilization at zero balance",
                value: chaseUtilizationString(facts: facts),
                evidence: .needsUserInput,
                note: "Assumes a zero current balance. The real value depends on statement timing and must come from the Chase app."
            ),
        ]
    }

    static func chaseUtilizationString(facts: ScenarioFacts) -> String {
        guard let util = facts.chaseUtilizationPercent(currentBalanceUSD: 0) else {
            return "Unknown"
        }
        return "≈ \(formatted(util * 100, fractionDigits: 1))% of USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0))"
    }

    // MARK: Option builders

    static func chaseOption(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> ScenarioPaymentOption {
        let guardrailsMet = state.chaseAvailableCreditConfirmed && state.canPayBeforeStatementClose
        let stance: ScenarioOptionStance = guardrailsMet
            ? .conditionallyPreferred
            : .needsVerification
        let util = facts.chaseUtilizationPercent(currentBalanceUSD: 0).map { $0 * 100 } ?? 0

        return ScenarioPaymentOption(
            method: .chaseFreedomRiseUSD,
            title: "Chase Freedom Rise (USD)",
            subtitle: "Pay USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) directly — U.S. card, U.S. merchant",
            costLabel: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2))",
            upside: "USD-on-USD with no Amazon ACC fee; possible 1.5% cash back (verify on official Chase page); builds U.S. credit activity.",
            downside: "At zero balance this reports ≈ \(formatted(util, fractionDigits: 1))% utilization of a USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)) limit if it posts before payment. Never carry a balance.",
            evidence: [.screenshotFact, .officialSource, .needsUserInput],
            stance: stance
        )
    }

    static func wiseOption(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> ScenarioPaymentOption {
        let stance: ScenarioOptionStance = state.wiseBalanceSufficient
            ? .safeFallback
            : .needsVerification

        return ScenarioPaymentOption(
            method: .wiseUSD,
            title: "Wise USD card or balance",
            subtitle: "Pay USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) straight from USD funds",
            costLabel: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2))",
            upside: "Protects Chase utilization entirely; per Wise, spending from a held currency is free when the balance covers the purchase.",
            downside: "Likely no card rewards; verify Amazon acceptance of the Wise card and whether Wise would auto-convert if the USD balance is short.",
            evidence: [.screenshotFact, .officialSource, .needsUserInput],
            stance: stance
        )
    }

    static func amexUSDOption(facts: ScenarioFacts) -> ScenarioPaymentOption {
        ScenarioPaymentOption(
            method: .amexCobaltUSD,
            title: "Amex Cobalt (Canada), charge in USD",
            subtitle: "Charge runs in USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)); Amex Canada then converts to CAD",
            costLabel: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) + unverified Amex FX commission",
            upside: "Avoids Amazon's ACC fee; Amex handles the conversion using Amex Canada's own rate and commission.",
            downside: "Amex Canada's foreign-currency conversion commission must be verified on the official Cardmember Agreement before this can be compared honestly. Amazon.com is not an eligible Cobalt 5x grocery / eats category — treat as 1x Membership Rewards.",
            evidence: [.screenshotFact, .needsUserInput, .inference],
            stance: .needsVerification
        )
    }

    static func amexCobaltACCOption(facts: ScenarioFacts) -> ScenarioPaymentOption {
        let feePercent = facts.accFeePercentOfPreFeeCAD * 100
        return ScenarioPaymentOption(
            method: .amexCobaltCADWithACC,
            title: "Amex Cobalt with Amazon Currency Converter (CAD)",
            subtitle: "Pay CAD \(formatted(facts.accCadTotal, fractionDigits: 2)) via ACC",
            costLabel: "CAD \(formatted(facts.accCadTotal, fractionDigits: 2))",
            upside: "Already linked to Amazon; no billing-address friction.",
            downside: "ACC embeds a CAD \(formatted(facts.accExplicitFeeCAD, fractionDigits: 2)) ≈ \(formatted(feePercent, fractionDigits: 2))% spread over Amazon's displayed CAD rate. Amazon.com remains 1x MR, not a 5x grocery / eats category.",
            evidence: [.screenshotFact, .officialSource, .inference],
            stance: .discouraged
        )
    }

    // MARK: Formatting

    /// Single formatter entry point so tests and UI copy agree on rounding.
    static func formatted(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .number.precision(.fractionLength(fractionDigits...fractionDigits))
        )
    }
}
