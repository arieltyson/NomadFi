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

    /// Produces the full decision brief for the given facts, the
    /// current user-confirmed state, and a catalog of source citations.
    static func decide(
        facts: ScenarioFacts,
        state: ScenarioDecisionState,
        citations: [ScenarioCitation] = ScenarioCitationCatalog.scenario1
    ) -> ScenarioDecision {
        let path = recommendedPath(facts: facts, state: state)
        let computed = computedValues(facts: facts, state: state)
        let ruling = ruling(for: path)
        let rationale = rationale(facts: facts, path: path, state: state, computed: computed)
        let outstanding = outstandingChecks(state: state, path: path)
        let options = paymentOptions(facts: facts, state: state, computed: computed)

        return ScenarioDecision(
            ruling: ruling,
            primaryPath: path,
            rationale: rationale,
            outstandingChecks: outstanding,
            paymentOptions: options,
            costBreakdown: costBreakdown(facts: facts, computed: computed),
            hardRules: hardRules,
            beforeCheckoutChecklist: beforeCheckoutChecklist,
            computedValues: computed,
            citations: citations
        )
    }

    // MARK: - Path selection

    /// Ordering:
    ///
    /// 1. Cart comes first — a cheaper card on a bloated cart saves nothing.
    /// 2. Chase Freedom Rise is only recommended when **all** four
    ///    user-entered guardrails clear: available credit known and
    ///    above checkout + buffer, current balance known, and the user
    ///    commits to paying before statement close.
    /// 3. Wise USD is the safe fallback — but only when the user has
    ///    confirmed a USD balance that covers the checkout.
    /// 4. Otherwise the engine refuses to pick, because it would be
    ///    guessing on someone else's money.
    static func recommendedPath(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> ScenarioRecommendedPath {
        guard state.cartShippingReviewed else {
            return .reviewCartFirst
        }

        if chaseGuardrailsMet(facts: facts, state: state) {
            return .chaseFreedomRiseUSD
        }

        if wiseGuardrailsMet(facts: facts, state: state) {
            return .wiseUSD
        }

        return .awaitingUserInput
    }

    /// Chase Freedom Rise is conditionally preferred only when every
    /// single guardrail below is satisfied with a user-confirmed value.
    ///
    /// In addition to the numeric guardrails, a credit-card account
    /// must be linked (the source of truth for the statement calendar)
    /// and that account's schedule must be complete, in-order, and
    /// confirmed. A missing or unconfirmed schedule blocks Chase even
    /// when every other numeric guardrail passes.
    static func chaseGuardrailsMet(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> Bool {
        guard let available = state.chaseAvailableCreditUSD else {
            return false
        }
        let required = facts.usdCheckoutAmount
            + ScenarioFacts.chaseAvailableCreditSafetyBufferUSD
        guard available >= required else { return false }
        guard state.chaseCurrentBalanceUSD != nil else { return false }
        guard state.chaseWillPayBeforeStatementClose else { return false }
        guard state.hasLinkedChaseAccount else { return false }
        guard state.linkedChaseScheduleState == .confirmed else { return false }
        return true
    }

    /// Wise USD is a safe fallback once the user has confirmed a USD
    /// balance that covers the checkout. Card acceptance is surfaced
    /// as an explicit outstanding check rather than a silent block.
    static func wiseGuardrailsMet(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> Bool {
        guard let wise = state.wiseUSDBalanceUSD else { return false }
        return wise >= facts.usdCheckoutAmount
    }

    // MARK: - Computed values

    static func computedValues(
        facts: ScenarioFacts,
        state: ScenarioDecisionState
    ) -> ScenarioComputedValues {
        let required = facts.usdCheckoutAmount
            + ScenarioFacts.chaseAvailableCreditSafetyBufferUSD

        let hasEnoughCredit: Bool? = state.chaseAvailableCreditUSD.map {
            $0 >= required
        }
        let wiseCovers: Bool? = state.wiseUSDBalanceUSD.map {
            $0 >= facts.usdCheckoutAmount
        }

        return ScenarioComputedValues(
            checkoutAmountUSD: facts.usdCheckoutAmount,
            chaseAvailableCreditSafetyBufferUSD: ScenarioFacts.chaseAvailableCreditSafetyBufferUSD,
            chaseRequiredAvailableCreditUSD: required,
            projectedChaseBalanceUSD: facts.projectedChaseBalanceUSD(
                currentBalanceUSD: state.chaseCurrentBalanceUSD
            ),
            projectedChaseUtilizationPercent: facts.projectedChaseUtilizationPercent(
                currentBalanceUSD: state.chaseCurrentBalanceUSD
            ),
            zeroBalanceChaseUtilizationPercent: facts.chaseUtilizationPercent(
                currentBalanceUSD: 0
            ),
            chaseHasSufficientAvailableCredit: hasEnoughCredit,
            wiseBalanceCoversCheckout: wiseCovers
        )
    }

    // MARK: - Payment option matrix

    static func paymentOptions(
        facts: ScenarioFacts,
        state: ScenarioDecisionState,
        computed: ScenarioComputedValues
    ) -> [ScenarioPaymentOption] {
        [
            chaseOption(facts: facts, state: state, computed: computed),
            wiseOption(facts: facts, state: state, computed: computed),
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
            id: "chase_account_linked",
            title: "Linked a Chase Freedom Rise credit-card account to this scenario",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "chase_schedule_confirmed",
            title: "Linked card's statement calendar is complete and confirmed in Settings",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "chase_available_credit_entered",
            title: "Chase Freedom Rise available credit entered and above USD checkout + safety buffer",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "chase_current_balance_entered",
            title: "Chase Freedom Rise current statement balance entered",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "chase_will_pay_before_statement_close",
            title: "Committed to paying the Chase balance before the next statement closes",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "wise_balance_entered",
            title: "Wise USD balance entered and covers the USD checkout amount",
            evidence: .needsUserInput
        ),
        ScenarioChecklistItem(
            id: "wise_card_accepted_by_amazon",
            title: "Wise card accepted by Amazon for this order",
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
            return "Review shipping first, then choose payment."
        case .chaseFreedomRiseUSD:
            return "Use Chase in USD, then pay before statement close."
        case .wiseUSD:
            return "Use Wise USD to avoid Chase utilization."
        case .awaitingUserInput:
            return "Pay in USD, but confirm Chase or Wise inputs before choosing."
        }
    }

    static func rationale(
        facts: ScenarioFacts,
        path: ScenarioRecommendedPath,
        state: ScenarioDecisionState,
        computed: ScenarioComputedValues
    ) -> [String] {
        var lines: [String] = []

        let feePercent = facts.accFeePercentOfPreFeeCAD * 100
        let effectiveRate = facts.accEffectiveRateCADperUSD
        lines.append(
            "Amazon Currency Converter adds CAD \(formatted(facts.accExplicitFeeCAD, fractionDigits: 2)) ≈ \(formatted(feePercent, fractionDigits: 2))% over Amazon's displayed CAD conversion — effective rate ≈ \(formatted(effectiveRate, fractionDigits: 4)) CAD/USD vs. displayed \(formatted(facts.amazonDisplayedRateCADperUSD, fractionDigits: 5))."
        )

        if let projectedUtil = computed.projectedChaseUtilizationPercent,
           let projectedBalance = computed.projectedChaseBalanceUSD {
            lines.append(
                "Projected Chase utilization after this order is ≈ \(formatted(projectedUtil * 100, fractionDigits: 1))% (USD \(formatted(projectedBalance, fractionDigits: 2)) against a USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)) limit) — based on the current balance you entered."
            )
        } else if let zeroUtil = computed.zeroBalanceChaseUtilizationPercent {
            lines.append(
                "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) is ≈ \(formatted(zeroUtil * 100, fractionDigits: 1))% of the Chase Freedom Rise USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)) total limit — a zero-balance reference. Enter your real Chase current balance for the projected number."
            )
        }

        switch path {
        case .reviewCartFirst:
            lines.append("Cart optimization has not been confirmed. Fix shipping before picking a card.")
        case .chaseFreedomRiseUSD:
            if let available = state.chaseAvailableCreditUSD {
                lines.append(
                    "Chase available credit of USD \(formatted(available, fractionDigits: 2)) comfortably covers the USD \(formatted(computed.chaseRequiredAvailableCreditUSD, fractionDigits: 2)) threshold (checkout + USD \(formatted(computed.chaseAvailableCreditSafetyBufferUSD, fractionDigits: 0)) buffer), and the balance will be paid before statement close."
                )
            }
            if let cardName = state.linkedChaseAccountName,
               let closing = state.effectiveChaseStatementCloseDate {
                lines.append(
                    "Linked card: \(cardName). Pay before \(closing.formatted(.dateTime.year().month(.wide).day())) to keep the statement balance low when it reports."
                )
            }
        case .wiseUSD:
            if !chaseGuardrailsMet(facts: facts, state: state) {
                lines.append("Chase guardrails are not all confirmed, so Wise USD is the safer operational path — it avoids reporting high Chase utilization to the bureaus entirely.")
            }
        case .awaitingUserInput:
            lines.append("Not enough user-confirmed inputs to pick between Chase and Wise. The ruling is a stance, not a selection.")
        }

        // Schedule signal is surfaced in the rationale regardless of
        // the chosen path, because it's the gate most likely to flip
        // between Chase-preferred and Wise-fallback.
        if let scheduleLine = scheduleRationaleLine(state: state) {
            lines.append(scheduleLine)
        }

        return lines
    }

    /// A single rationale line that describes the linked-card schedule
    /// status, using absolute dates only — HIG forbids relative phrasing.
    static func scheduleRationaleLine(state: ScenarioDecisionState) -> String? {
        guard state.hasLinkedChaseAccount else {
            return "No Chase card is linked to this scenario yet — link one from the Chase section to unlock the Chase path."
        }
        guard let schedule = state.linkedChaseSchedule else { return nil }

        switch schedule.state {
        case .confirmed:
            if let cardName = state.linkedChaseAccountName,
               let closing = schedule.statementClosingDate {
                return "Linked card \(cardName) has a confirmed statement calendar (closes \(closing.formatted(.dateTime.year().month(.wide).day())))."
            }
            return nil
        case .partial:
            return "Linked Chase card's statement calendar is partial — complete it in Settings → Credit Card Calendar to unlock Chase."
        case .needsAttention:
            return "Linked Chase card's statement dates are in an invalid order — review them in Settings → Credit Card Calendar."
        case .missing:
            return "Linked Chase card has no statement calendar yet — enter it in Settings → Credit Card Calendar to unlock Chase."
        }
    }

    static func outstandingChecks(
        state: ScenarioDecisionState,
        path: ScenarioRecommendedPath
    ) -> [String] {
        var checks: [String] = []

        if !state.cartShippingReviewed {
            checks.append("Review the cart for paid / overnight shipping and accidental Subscribe & Save.")
        }
        if !state.hasLinkedChaseAccount {
            checks.append("Link a Chase Freedom Rise credit-card account to this scenario.")
        } else if let scheduleState = state.linkedChaseScheduleState,
                  scheduleState != .confirmed {
            switch scheduleState {
            case .missing:
                checks.append("Add the linked Chase card's statement calendar in Settings → Credit Card Calendar.")
            case .partial:
                checks.append("Complete the linked Chase card's statement calendar in Settings → Credit Card Calendar.")
            case .needsAttention:
                checks.append("Resolve the linked Chase card's date order in Settings → Credit Card Calendar.")
            case .confirmed:
                break
            }
        }
        if state.chaseAvailableCreditUSD == nil {
            checks.append("Enter Chase Freedom Rise available credit from the Chase app.")
        }
        if state.chaseCurrentBalanceUSD == nil {
            checks.append("Enter the current Chase Freedom Rise statement balance from the Chase app.")
        }
        if !state.chaseWillPayBeforeStatementClose {
            checks.append("Commit to paying the Chase balance before the next statement closes.")
        }
        if state.wiseUSDBalanceUSD == nil {
            checks.append("Enter the USD balance in Wise.")
        }
        if !state.wiseCardAcceptedByAmazon {
            checks.append("Confirm the Wise card is accepted by Amazon before treating Wise as the fallback.")
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

    static func costBreakdown(
        facts: ScenarioFacts,
        computed: ScenarioComputedValues
    ) -> [ScenarioCostLine] {
        let feePercent = facts.accFeePercentOfPreFeeCAD * 100

        var lines: [ScenarioCostLine] = [
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
                label: "Chase utilization if paid off",
                value: zeroBalanceUtilizationString(facts: facts, computed: computed),
                evidence: .inference,
                note: "Reference only — assumes a zero current balance."
            ),
        ]

        if let projected = computed.projectedChaseUtilizationPercent,
           let projectedBalance = computed.projectedChaseBalanceUSD {
            lines.append(
                ScenarioCostLine(
                    id: "chase_projected_utilization",
                    label: "Chase projected utilization after this order",
                    value: "≈ \(formatted(projected * 100, fractionDigits: 1))% (USD \(formatted(projectedBalance, fractionDigits: 2)) of USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)))",
                    evidence: .inference,
                    note: "Current balance user-confirmed. Utilization is a projection, not a statement fact."
                )
            )
        }

        return lines
    }

    static func zeroBalanceUtilizationString(
        facts: ScenarioFacts,
        computed: ScenarioComputedValues
    ) -> String {
        guard let util = computed.zeroBalanceChaseUtilizationPercent else {
            return "Unknown"
        }
        return "≈ \(formatted(util * 100, fractionDigits: 1))% of USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0))"
    }

    // MARK: Option builders

    static func chaseOption(
        facts: ScenarioFacts,
        state: ScenarioDecisionState,
        computed: ScenarioComputedValues
    ) -> ScenarioPaymentOption {
        let guardrailsMet = chaseGuardrailsMet(facts: facts, state: state)
        let stance: ScenarioOptionStance = guardrailsMet
            ? .conditionallyPreferred
            : .needsVerification

        let utilText: String = {
            if let projected = computed.projectedChaseUtilizationPercent {
                "projects to ≈ \(formatted(projected * 100, fractionDigits: 1))% utilization with your current balance"
            } else if let zero = computed.zeroBalanceChaseUtilizationPercent {
                "≈ \(formatted(zero * 100, fractionDigits: 1))% utilization if paid off"
            } else {
                "utilization unknown without user input"
            }
        }()

        return ScenarioPaymentOption(
            method: .chaseFreedomRiseUSD,
            title: "Chase Freedom Rise (USD)",
            subtitle: "Pay USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) directly — U.S. card, U.S. merchant",
            costLabel: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2))",
            upside: "USD-on-USD with no Amazon ACC fee; possible 1.5% cash back (verify on official Chase page); builds U.S. credit activity.",
            downside: "This \(utilText) against a USD \(formatted(facts.chaseTotalCreditLimitUSD, fractionDigits: 0)) limit. Never carry a balance at the purchase APR.",
            evidence: [.screenshotFact, .officialSource, .needsUserInput],
            stance: stance
        )
    }

    static func wiseOption(
        facts: ScenarioFacts,
        state: ScenarioDecisionState,
        computed: ScenarioComputedValues
    ) -> ScenarioPaymentOption {
        let stance: ScenarioOptionStance = wiseGuardrailsMet(facts: facts, state: state)
            ? .safeFallback
            : .needsVerification

        let balanceNote: String
        if let covers = computed.wiseBalanceCoversCheckout, covers {
            balanceNote = "Wise USD balance covers the USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) checkout."
        } else if computed.wiseBalanceCoversCheckout == false {
            balanceNote = "Wise USD balance is below the USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) checkout — topping up or choosing Chase is required before this is a real option."
        } else {
            balanceNote = "Enter the USD balance in Wise so the engine can confirm it covers the checkout."
        }

        return ScenarioPaymentOption(
            method: .wiseUSD,
            title: "Wise USD card or balance",
            subtitle: "Pay USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2)) straight from USD funds",
            costLabel: "USD \(formatted(facts.usdCheckoutAmount, fractionDigits: 2))",
            upside: "Protects Chase utilization entirely; per Wise, spending from a held currency is free when the balance covers the purchase.",
            downside: "\(balanceNote) Confirm Amazon acceptance of the Wise card and watch for auto-conversion if the balance is short.",
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
