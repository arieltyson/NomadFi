// ScenarioDecisionEngineTests.swift
// NomadFi
//
// Pure-logic coverage for the Scenario 1 decision engine.
// These tests pin the numbers the dashboard card and detail sheet
// advertise to the user, and the branching behavior of the engine —
// now driven by typed, user-confirmed inputs rather than booleans.

import Foundation
import Testing

@testable import NomadFi

struct ScenarioDecisionEngineTests {

    // MARK: - Helpers

    /// Fully-populated guardrail state: cart reviewed, Chase available
    /// credit comfortably above checkout + buffer, current balance set,
    /// and the user committed to paying before statement close.
    private static func chaseGuardrailedState(
        currentBalanceUSD: Double = 0
    ) -> ScenarioDecisionState {
        ScenarioDecisionState(
            cartShippingReviewed: true,
            chaseAvailableCreditUSD: 500,
            chaseCurrentBalanceUSD: currentBalanceUSD,
            chaseWillPayBeforeStatementClose: true
        )
    }

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

    @Test("Projected utilization uses the user-entered current balance, not the zero-balance assumption")
    func projectedUtilizationPrefersEnteredBalance() {
        let facts = ScenarioFacts.scenario1

        // User-entered current balance of USD 50
        let projected = facts.projectedChaseUtilizationPercent(
            currentBalanceUSD: 50
        ) ?? 0
        // (50 + 342.67) / 500 = 0.78534 → ~78.5%
        #expect(projected > 0.784)
        #expect(projected < 0.786)

        // Nil when no current balance is supplied.
        #expect(facts.projectedChaseUtilizationPercent(currentBalanceUSD: nil) == nil)
        #expect(facts.projectedChaseBalanceUSD(currentBalanceUSD: nil) == nil)
    }

    // MARK: - Engine branching

    @Test("A blank state keeps the decision at review-cart-first (cart defaults to unreviewed)")
    func blankStateDefaultsToReviewCartFirst() {
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: ScenarioDecisionState()
        )
        #expect(decision.primaryPath == .reviewCartFirst)
    }

    @Test("Cart reviewed with every other input blank keeps the engine in awaiting-user-input")
    func cartReviewedAloneBlocksOnInputs() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .awaitingUserInput)
    }

    @Test("Chase is not recommended when available credit is nil")
    func chaseNotRecommendedWhenAvailableCreditNil() {
        var state = Self.chaseGuardrailedState()
        state.chaseAvailableCreditUSD = nil

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .chaseFreedomRiseUSD)
    }

    @Test("Chase is not recommended when available credit is below checkout + buffer")
    func chaseNotRecommendedWhenAvailableCreditBelowThreshold() {
        var state = Self.chaseGuardrailedState()
        // Required threshold: 342.67 + 50 = 392.67. This is below.
        state.chaseAvailableCreditUSD = 390

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .chaseFreedomRiseUSD)
    }

    @Test("Chase is not recommended when the current balance is nil")
    func chaseNotRecommendedWhenCurrentBalanceNil() {
        var state = Self.chaseGuardrailedState()
        state.chaseCurrentBalanceUSD = nil

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .chaseFreedomRiseUSD)
    }

    @Test("Chase is not recommended when the user has not committed to paying before statement close")
    func chaseNotRecommendedWhenWillNotPayBeforeClose() {
        var state = Self.chaseGuardrailedState()
        state.chaseWillPayBeforeStatementClose = false

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .chaseFreedomRiseUSD)
    }

    @Test("Chase is recommended when cart is reviewed, credit clears buffer, balance known, and user will pay before close")
    func chaseRecommendedWhenAllGuardrailsMet() {
        let state = Self.chaseGuardrailedState()
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .chaseFreedomRiseUSD)
    }

    @Test("Wise is recommended when Wise USD balance covers checkout and Chase guardrails are missing")
    func wiseRecommendedAsFallback() {
        let state = ScenarioDecisionState(
            cartShippingReviewed: true,
            wiseUSDBalanceUSD: 500
        )
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .wiseUSD)
    }

    @Test("Wise is not recommended when Wise USD balance is below checkout")
    func wiseNotRecommendedWhenBelowCheckout() {
        let state = ScenarioDecisionState(
            cartShippingReviewed: true,
            wiseUSDBalanceUSD: 100
        )
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath != .wiseUSD)
        #expect(decision.primaryPath == .awaitingUserInput)
    }

    @Test("Blocks on user input when cart is reviewed but neither Chase nor Wise inputs are set")
    func blocksWhenNothingIsConfirmed() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .awaitingUserInput)
    }

    @Test("Cart optimization precedes payment selection")
    func cartOptimizationPrecedesEverything() {
        var state = Self.chaseGuardrailedState()
        state.cartShippingReviewed = false

        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        #expect(decision.primaryPath == .reviewCartFirst)
    }

    // MARK: - Rulings

    @Test("Chase-qualified ruling matches the user-facing copy")
    func chaseRulingCopy() {
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: Self.chaseGuardrailedState()
        )
        #expect(decision.ruling == "Use Chase in USD, then pay before statement close.")
    }

    @Test("Wise-qualified ruling matches the user-facing copy")
    func wiseRulingCopy() {
        let state = ScenarioDecisionState(
            cartShippingReviewed: true,
            wiseUSDBalanceUSD: 500
        )
        let decision = ScenarioDecisionEngine.decide(facts: .scenario1, state: state)
        #expect(decision.ruling == "Use Wise USD to avoid Chase utilization.")
    }

    @Test("Blocked ruling matches the user-facing copy")
    func blockedRulingCopy() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        let decision = ScenarioDecisionEngine.decide(facts: .scenario1, state: state)
        #expect(decision.ruling == "Pay in USD, but confirm Chase or Wise inputs before choosing.")
    }

    @Test("Review-cart ruling matches the user-facing copy")
    func cartRulingCopy() {
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: ScenarioDecisionState()
        )
        #expect(decision.ruling == "Review shipping first, then choose payment.")
    }

    // MARK: - Computed values on the decision

    @Test("Computed values reflect entered Chase current balance, not the zero-balance reference")
    func computedValuesUseEnteredBalance() {
        var state = Self.chaseGuardrailedState(currentBalanceUSD: 50)
        state.chaseAvailableCreditUSD = 500

        let decision = ScenarioDecisionEngine.decide(facts: .scenario1, state: state)
        let projected = decision.computedValues.projectedChaseUtilizationPercent
        let projectedBalance = decision.computedValues.projectedChaseBalanceUSD

        // (50 + 342.67) / 500 = 0.78534
        #expect((projected ?? 0) > 0.784)
        #expect((projected ?? 0) < 0.786)
        #expect(abs((projectedBalance ?? 0) - 392.67) < 0.01)

        // Zero-balance reference remains visible for comparison.
        let zero = decision.computedValues.zeroBalanceChaseUtilizationPercent ?? 0
        #expect(zero > 0.684 && zero < 0.686)
    }

    @Test("Computed values surface Chase coverage and Wise coverage flags")
    func computedValuesSurfaceCoverageFlags() {
        let state = ScenarioDecisionState(
            cartShippingReviewed: true,
            chaseAvailableCreditUSD: 500,
            chaseCurrentBalanceUSD: 0,
            chaseWillPayBeforeStatementClose: true,
            wiseUSDBalanceUSD: 500
        )
        let decision = ScenarioDecisionEngine.decide(facts: .scenario1, state: state)
        #expect(decision.computedValues.chaseHasSufficientAvailableCredit == true)
        #expect(decision.computedValues.wiseBalanceCoversCheckout == true)

        // Flip both below threshold and retest.
        let weak = ScenarioDecisionState(
            cartShippingReviewed: true,
            chaseAvailableCreditUSD: 200,
            wiseUSDBalanceUSD: 100
        )
        let weakDecision = ScenarioDecisionEngine.decide(facts: .scenario1, state: weak)
        #expect(weakDecision.computedValues.chaseHasSufficientAvailableCredit == false)
        #expect(weakDecision.computedValues.wiseBalanceCoversCheckout == false)
    }

    // MARK: - Citations

    @Test("Decision carries a non-empty citation catalog by default")
    func decisionCarriesCitations() {
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: ScenarioDecisionState()
        )
        #expect(!decision.citations.isEmpty)
        // Each citation is an official source pointer the user can verify.
        #expect(decision.citations.allSatisfy { $0.evidence == .officialSource })
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

        #expect(amex.downside.localizedStandardContains("1x Membership Rewards"))
        #expect(!amex.downside.localizedStandardContains("earns 5x"))
        #expect(!amex.upside.localizedStandardContains("5x"))
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

    @Test("Wise USD is the safe fallback only after the Wise balance covers the checkout")
    func wiseIsFallbackOnlyWhenConfirmed() {
        var state = ScenarioDecisionState(cartShippingReviewed: true)
        let unconfirmed = ScenarioDecisionEngine
            .decide(facts: .scenario1, state: state)
            .paymentOptions
            .first { $0.method == .wiseUSD }
        #expect(unconfirmed?.stance == .needsVerification)

        state.wiseUSDBalanceUSD = 500
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
