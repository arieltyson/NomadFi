// DecisionAssistantIntentDialogTests.swift
// NomadFi
//
// Focused tests for the pure dialog builders that sit behind the
// Decision Assistant's App Intents. These tests do not touch AppIntents
// or SwiftData — they exercise the formatter directly with engine
// output so regressions in voice copy are catchable without an Xcode
// UI test run.
//
// The key properties under test:
//
//   - "Which card?" no longer answers from foreign-transaction-fee
//     data. The rewritten path must defer to Scenario 1 and refuse to
//     invent a merchant-agnostic recommendation.
//   - A Scenario 1 record with no user inputs must produce a
//     missing-inputs caveat, not a fabricated ruling.
//   - A populated Scenario 1 record must route the dialog through
//     `ScenarioDecisionEngine` — the ruling string in the dialog must
//     match the engine's ruling string.
//   - Outstanding-check counts are spoken in natural English, not as
//     raw numbers, and "0 checks" turns into "No outstanding checks".

import Foundation
import Testing

@testable import NomadFi

struct DecisionAssistantIntentDialogTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private static var confirmedSchedule: CreditCardSchedule {
        CreditCardSchedule(
            statementPeriodStartDate: date(year: 2026, month: 4, day: 1),
            statementClosingDate: date(year: 2026, month: 4, day: 28),
            paymentDueDate: date(year: 2026, month: 5, day: 25),
            lastConfirmedAt: date(year: 2026, month: 4, day: 21)
        )
    }

    /// A blank scenario state — mirrors what a freshly-created Scenario
    /// 1 record projects to before the user has opened the brief.
    private static let blankState = ScenarioDecisionState()

    /// A fully-populated state that clears every Chase guardrail, so
    /// the engine returns `.chaseFreedomRiseUSD`.
    private static let chasePreferredState = ScenarioDecisionState(
        cartShippingReviewed: true,
        chaseAvailableCreditUSD: 500,
        chaseCurrentBalanceUSD: 0,
        chaseWillPayBeforeStatementClose: true,
        wiseUSDBalanceUSD: 500,
        wiseCardAcceptedByAmazon: true,
        hasLinkedChaseAccount: true,
        linkedChaseAccountName: "Sample Rewards",
        linkedChaseSchedule: confirmedSchedule
    )

    private static func brief(
        state: ScenarioDecisionState,
        hasInteractedOverride: Bool? = nil
    ) -> DecisionAssistantIntentDialog.ScenarioBriefContext {
        let decision = ScenarioDecisionEngine.decide(
            facts: .scenario1,
            state: state
        )
        let hasInteracted = hasInteractedOverride
            ?? DecisionAssistantIntentContext.hasInteracted(with: state)
        return DecisionAssistantIntentDialog.ScenarioBriefContext(
            decision: decision,
            hasInteractedWithInputs: hasInteracted
        )
    }

    // MARK: - "Which card?" rewrite

    @Test("whichCardAnswer refuses the merchant-agnostic framing and names Amazon arrival only")
    func whichCardAnswerMentionsLimitedCoverage() {
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(
            brief: Self.brief(state: Self.blankState)
        )
        #expect(dialog.contains("can't yet answer which card to use for any merchant"))
        #expect(dialog.contains("Amazon arrival order"))
    }

    @Test("whichCardAnswer never references foreign transaction fee ranking")
    func whichCardAnswerHasNoFXFeeCopy() {
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(
            brief: Self.brief(state: Self.chasePreferredState)
        )
        // The old path answered "lowest foreign transaction fee on record".
        // The rewrite must not reintroduce that framing.
        #expect(!dialog.contains("foreign transaction fee"))
        #expect(!dialog.contains("lowest"))
    }

    @Test("whichCardAnswer with no inputs produces a missing-checks caveat")
    func whichCardAnswerMissingInputsCaveat() {
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(
            brief: Self.brief(state: Self.blankState)
        )
        #expect(dialog.contains("doesn't have your inputs yet"))
        #expect(dialog.contains("Decisions tab"))
    }

    @Test("whichCardAnswer with populated Chase state echoes the engine ruling")
    func whichCardAnswerEchoesEngineRuling() {
        let brief = Self.brief(state: Self.chasePreferredState)
        let dialog = DecisionAssistantIntentDialog.whichCardAnswer(brief: brief)
        // The engine ruling for a fully-populated Chase guardrailed
        // state is "Use Chase in USD, then pay before statement close."
        #expect(brief.decision.primaryPath == .chaseFreedomRiseUSD)
        #expect(dialog.contains(brief.decision.ruling))
    }

    // MARK: - Review path

    @Test("amazonArrivalReview with no inputs asks the user to populate the record")
    func reviewDialogEmptyStateIsHonest() {
        let dialog = DecisionAssistantIntentDialog.amazonArrivalReview(
            brief: Self.brief(state: Self.blankState)
        )
        #expect(dialog.contains("doesn't have your inputs yet"))
        // Missing-inputs copy must not try to announce a ruling.
        #expect(!dialog.contains("Use Chase"))
        #expect(!dialog.contains("Use Wise"))
    }

    @Test("amazonArrivalReview with populated Chase state echoes the engine and names zero checks correctly")
    func reviewDialogChasePathPluralization() {
        let brief = Self.brief(state: Self.chasePreferredState)
        let dialog = DecisionAssistantIntentDialog.amazonArrivalReview(brief: brief)

        #expect(brief.decision.primaryPath == .chaseFreedomRiseUSD)
        #expect(dialog.contains(brief.decision.ruling))

        if brief.decision.outstandingChecks.isEmpty {
            #expect(dialog.contains("No outstanding checks remain."))
        } else {
            // If the engine still has residual verification checks
            // (Amex and Chase cash-back are always listed as
            // cross-cutting verifications), pluralization must match.
            let count = brief.decision.outstandingChecks.count
            let expectedPhrase = count == 1 ? "1 check" : "\(count) checks"
            #expect(dialog.contains(expectedPhrase))
        }
    }

    @Test("amazonArrivalReview with partial inputs surfaces the awaiting-user-input tail")
    func reviewDialogAwaitingInputTail() {
        // Cart reviewed so we move past `reviewCartFirst`, but no Chase
        // or Wise inputs, so the engine returns `.awaitingUserInput`.
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        let brief = Self.brief(state: state, hasInteractedOverride: true)
        let dialog = DecisionAssistantIntentDialog.amazonArrivalReview(brief: brief)

        #expect(brief.decision.primaryPath == .awaitingUserInput)
        #expect(dialog.contains("Open NomadFi's Decisions tab to finish the brief before NomadFi picks a card."))
    }

    // MARK: - Continue path

    @Test("continueAmazonArrivalDecision announces the ruling when inputs exist")
    func continueDialogIncludesRuling() {
        let brief = Self.brief(state: Self.chasePreferredState)
        let dialog = DecisionAssistantIntentDialog.continueAmazonArrivalDecision(
            brief: brief
        )
        #expect(dialog.contains("Opening your Amazon arrival decision"))
        #expect(dialog.contains(brief.decision.ruling))
    }

    @Test("continueAmazonArrivalDecision still mentions missing inputs when the record is blank")
    func continueDialogBlankRecord() {
        let dialog = DecisionAssistantIntentDialog.continueAmazonArrivalDecision(
            brief: Self.brief(state: Self.blankState)
        )
        #expect(dialog.contains("Opening NomadFi to your Amazon arrival decision"))
        #expect(dialog.contains("enter your cart, Chase, and Wise details"))
    }

    // MARK: - Open path

    @Test("openDecisionAssistant dialog names current coverage honestly")
    func openDialogIsHonest() {
        let dialog = DecisionAssistantIntentDialog.openDecisionAssistant
        #expect(dialog.contains("Opening your Decision Assistant"))
        #expect(dialog.contains("Amazon arrival order"))
    }

    // MARK: - hasInteracted helper

    @Test("hasInteracted returns false for a freshly-created state")
    func hasInteractedFalseForBlank() {
        #expect(
            !DecisionAssistantIntentContext.hasInteracted(with: ScenarioDecisionState())
        )
    }

    @Test("hasInteracted returns true once any meaningful input flips")
    func hasInteractedTrueOnAnyInput() {
        var state = ScenarioDecisionState()
        state.cartShippingReviewed = true
        #expect(DecisionAssistantIntentContext.hasInteracted(with: state))

        var credit = ScenarioDecisionState()
        credit.chaseAvailableCreditUSD = 500
        #expect(DecisionAssistantIntentContext.hasInteracted(with: credit))

        var link = ScenarioDecisionState()
        link.hasLinkedChaseAccount = true
        #expect(DecisionAssistantIntentContext.hasInteracted(with: link))
    }

    // MARK: - Tab routing

    @Test("MainTabSelection raw values are stable so App Intent UserDefaults writes persist")
    func tabSelectionRawValuesAreStable() {
        #expect(MainTabSelection.dashboard.rawValue == "dashboard")
        #expect(MainTabSelection.decisions.rawValue == "decisions")
        #expect(MainTabSelection.settings.rawValue == "settings")
        #expect(MainTabSelection.default == .dashboard)
    }
}
