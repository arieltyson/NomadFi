// ScenarioDecisionEngineTests.swift
// NomadFi
//
// Pure-logic coverage for the Scenario 1 decision engine.
// These tests pin the numbers the dashboard card and detail sheet
// advertise to the user, and the branching behavior of the engine.

import Foundation
import Testing

@testable import NomadFi

struct ScenarioDecisionEngineTests {

    // MARK: - Math

    @Test("ACC fee is ~2.78% of the pre-fee CAD amount, not a direct CAD/USD percent")
    func accFeePercentIsTwoPointSevenEight() {
        let facts = ScenarioFacts.scenario1

        // 13.00 / (342.67 * 1.36528) ≈ 0.02778
        let percent = facts.accFeePercentOfPreFeeCAD * 100
        #expect(percent > 2.77)
        #expect(percent < 2.79)

        // Explicitly reject the old 3.79% framing.
        let wrongDirectRatio = facts.accExplicitFeeCAD / facts.usdCheckoutAmount * 100
        #expect(wrongDirectRatio > 3.7)
        #expect(percent < wrongDirectRatio)
    }

    @Test("Effective ACC rate is ~1.4032 CAD/USD")
    func accEffectiveRateIsOneFourZeroThreeTwo() {
        let facts = ScenarioFacts.scenario1
        // 480.86 / 342.67 ≈ 1.40316 → rounds to 1.4032
        let rate = facts.accEffectiveRateCADperUSD
        #expect(rate > 1.4030)
        #expect(rate < 1.4034)
    }

    @Test("Pre-fee CAD amount is ~467.84 (not 467.86 as an earlier revision rounded)")
    func preFeeCADIsFourSixSevenPointEightFour() {
        let facts = ScenarioFacts.scenario1
        let preFee = facts.preACCFeeCAD
        #expect(abs(preFee - 467.84) < 0.01)
    }

    // MARK: - Chase utilization

    @Test("Chase utilization is derived from the total limit only when a balance is given or assumed zero")
    func chaseUtilizationIsBalanceSensitive() {
        let facts = ScenarioFacts.scenario1

        // At zero balance: 342.67 / 500 ≈ 0.6853 → ~68.5%
        let atZero = facts.chaseUtilizationPercent(currentBalanceUSD: 0) ?? 0
        #expect(atZero > 0.684)
        #expect(atZero < 0.686)

        // With an existing USD 100 balance, utilization goes up materially.
        let withExisting = facts.chaseUtilizationPercent(currentBalanceUSD: 100) ?? 0
        #expect(withExisting > atZero)
        #expect(withExisting > 0.88 && withExisting < 0.90)
    }

    @Test("Chase utilization is nil when the credit limit is non-positive")
    func chaseUtilizationGuardsAgainstZeroLimit() {
        let facts = ScenarioFacts(
            usdCheckoutAmount: 342.67,
            accCadTotal: 480.86,
            accExplicitFeeCAD: 13.00,
            amazonDisplayedRateCADperUSD: 1.36528,
            chaseTotalCreditLimitUSD: 0,
            chasePurchaseAPRPercent: 25.24
        )
        #expect(facts.chaseUtilizationPercent(currentBalanceUSD: 0) == nil)
    }

    // MARK: - Engine branching

    @Test("Never recommends Chase when available credit / statement-close ability are not confirmed")
    func neverRecommendsChaseUnconditionally() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        // Both guardrails still false:
        state.chaseAvailableCreditConfirmed = false
        state.canPayBeforeStatementClose = false

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .chaseFreedomRiseUSD)
    }

    @Test("Recommends Wise USD when Chase guardrails are false but the Wise balance is confirmed")
    func recommendsWiseWhenChaseGuardrailsAreFalse() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        state.chaseAvailableCreditConfirmed = false
        state.canPayBeforeStatementClose = false
        state.wiseBalanceSufficient = true

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .wiseUSD)
    }

    @Test("Recommends Chase only when both utilization guardrails are true")
    func recommendsChaseWhenGuardrailsAreTrue() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        state.chaseAvailableCreditConfirmed = true
        state.canPayBeforeStatementClose = true

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .chaseFreedomRiseUSD)
    }

    @Test("Blocks on user input when neither Chase nor Wise are confirmed")
    func blocksWhenNothingIsConfirmed() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        // All other flags default to false.

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .awaitingUserInput)
    }

    @Test("Cart optimization precedes payment selection")
    func cartOptimizationPrecedesEverything() {
        var state = ScenarioDecisionState()
        state.chaseAvailableCreditConfirmed = true
        state.canPayBeforeStatementClose = true
        state.wiseBalanceSufficient = true
        state.cartShippingReviewed = false

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .reviewCartFirst)
    }

    // MARK: - Option matrix

    @Test("Amex Cobalt in USD is labeled 'needs verification' until FX commission is verified")
    func amexUSDIsNeedsVerification() {
        let state = ScenarioDecisionState()
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        let amex = decision.paymentOptions.first { $0.method == .amexCobaltUSD }
        #expect(amex?.stance == .needsVerification)
    }

    @Test("Engine does NOT treat Amazon.com as a Cobalt 5x grocery / eats category")
    func amazonIsNotACobaltFiveXCategory() {
        let state = ScenarioDecisionState()
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        guard let amex = decision.paymentOptions.first(where: { $0.method == .amexCobaltUSD }) else {
            Issue.record("Amex Cobalt USD option missing from payment matrix")
            return
        }

        // The engine must name the 1x MR outcome explicitly.
        #expect(amex.downside.localizedStandardContains("1x Membership Rewards"))
        // And must never claim Amazon *earns* 5x on Cobalt.
        #expect(!amex.downside.localizedStandardContains("earns 5x"))
        #expect(!amex.upside.localizedStandardContains("5x"))
        // Amex USD is never a preferred pick until the FX commission is verified.
        #expect(amex.stance == .needsVerification)
    }

    @Test("ACC-in-CAD option is discouraged")
    func accCADOptionIsDiscouraged() {
        let state = ScenarioDecisionState()
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        let acc = decision.paymentOptions.first { $0.method == .amexCobaltCADWithACC }
        #expect(acc?.stance == .discouraged)
    }

    @Test("Wise USD is the safe fallback only after the Wise balance is confirmed")
    func wiseIsFallbackOnlyWhenConfirmed() {
        var state = ScenarioDecisionState()
        state.wiseBalanceSufficient = false
        let unconfirmed = ScenarioDecisionEngine
            .decide(facts: .scenario1, state: state)
            .paymentOptions
            .first { $0.method == .wiseUSD }
        #expect(unconfirmed?.stance == .needsVerification)

        state.wiseBalanceSufficient = true
        let confirmed = ScenarioDecisionEngine
            .decide(facts: .scenario1, state: state)
            .paymentOptions
            .first { $0.method == .wiseUSD }
        #expect(confirmed?.stance == .safeFallback)
    }

    @Test("Hard rules explicitly forbid carrying a Chase balance for rewards")
    func hardRulesForbidCarryingAChaseBalance() {
        let rulesText = ScenarioDecisionEngine.hardRules.joined(separator: " ")
        #expect(rulesText.localizedStandardContains("Chase"))
        #expect(rulesText.localizedStandardContains("balance"))
        #expect(rulesText.localizedStandardContains("rewards"))
    }
}
