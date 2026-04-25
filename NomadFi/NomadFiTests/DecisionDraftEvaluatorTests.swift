// DecisionDraftEvaluatorTests.swift
// NomadFi
//
// Phase 1 follow-through coverage. Pure-logic tests over the
// `DecisionDraftEvaluator` derivation rules. `DecisionDraftRecord`
// is a SwiftData `@Model`, so the @MainActor annotation lets the
// suite construct fresh records without inserting them into a
// `ModelContainer` (matches the existing
// `DecisionDraftRecordTests` pattern).
//
// Pinned product contract:
//
//   • Drafts are never auto-analyzed by the evaluator. The output
//     is a *description* of what NomadFi can do.
//   • Recommendation language is forbidden in headlines and labels.
//   • Tax / Investing drafts emit a calm "Review in …" reminder
//     only — no cross-tab deep link.
//   • `.other` drafts emit a `noEngineYet` action with no handoff.
//   • Purchase / Travel without a positive amount emit an
//     `addContext(.amount)` reminder, not a handoff.
//   • Credit-timing without a saved credit card emits an
//     `addContext(.savedCreditCard)` reminder, not a handoff.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct DecisionDraftEvaluatorTests {

    // MARK: - Helpers

    private func draft(
        kind: DecisionDraftKind,
        amount: Double? = nil,
        merchant: String = "",
        location: String = "",
        timing: String = "",
        currency: CurrencyCode = .usd
    ) -> DecisionDraftRecord {
        DecisionDraftRecord(
            title: "Test draft",
            scenarioText: "Test scenario.",
            kind: kind,
            merchantName: merchant,
            locationText: location,
            amount: amount,
            currencyCode: currency,
            timingText: timing
        )
    }

    // MARK: - Purchase

    @Test("Purchase draft with a positive amount is engineReady and emits a single openPurchaseCheck handoff")
    func purchaseWithAmountIsEngineReady() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .purchase, amount: 80)
        )
        #expect(result.engineCoverage == .engineReady)
        #expect(result.nextActions.map(\.id) == [
            DecisionDraftNextAction.openPurchaseCheck.id,
        ])
        let handoff = result.primaryHandoff
        #expect(handoff == .openPurchaseCheck)
    }

    @Test("Purchase draft without an amount surfaces an addContext(.amount) reminder, not a handoff")
    func purchaseWithoutAmountAsksForAmount() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .purchase, amount: nil)
        )
        if case .engineRequiresMoreContext(let missing) = result.engineCoverage {
            #expect(missing == ["amount"])
        } else {
            Issue.record("Expected .engineRequiresMoreContext, got \(result.engineCoverage)")
        }
        #expect(result.primaryHandoff == nil)
        #expect(result.nextActions.contains(.addContext(field: .amount)))
    }

    @Test("Purchase draft with a zero amount also asks for an amount")
    func purchaseWithZeroAmountAsksForAmount() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .purchase, amount: 0)
        )
        #expect(result.primaryHandoff == nil)
        #expect(result.nextActions.contains(.addContext(field: .amount)))
    }

    // MARK: - Travel

    @Test("Travel draft with a positive amount is engineReady and emits openPurchaseCheck handoff")
    func travelWithAmountIsEngineReady() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .travel, amount: 250, location: "Lisbon")
        )
        #expect(result.engineCoverage == .engineReady)
        #expect(result.primaryHandoff == .openPurchaseCheck)
    }

    @Test("Travel draft without an amount asks for an amount")
    func travelWithoutAmountAsksForAmount() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .travel, amount: nil, location: "Lisbon")
        )
        #expect(result.primaryHandoff == nil)
        #expect(result.nextActions.contains(.addContext(field: .amount)))
    }

    // MARK: - Credit timing

    @Test("Credit-timing draft with a saved credit card on file is engineReady and emits openCreditTimingCheck")
    func creditTimingWithCardIsEngineReady() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .creditTiming),
            accountSnapshot: DecisionDraftAccountSnapshot(hasAnyCreditCard: true)
        )
        #expect(result.engineCoverage == .engineReady)
        #expect(result.primaryHandoff == .openCreditTimingCheck)
    }

    @Test("Credit-timing draft without any saved credit card asks the user to add one — no handoff")
    func creditTimingWithoutCardAsksForCard() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .creditTiming),
            accountSnapshot: .empty
        )
        if case .engineRequiresMoreContext(let missing) = result.engineCoverage {
            #expect(missing == ["savedCreditCard"])
        } else {
            Issue.record("Expected .engineRequiresMoreContext, got \(result.engineCoverage)")
        }
        #expect(result.primaryHandoff == nil)
        #expect(result.nextActions.contains(.addContext(field: .savedCreditCard)))
    }

    // MARK: - Tax / Investing learn (no deep link)

    @Test("Tax-education draft routes to Tax Vault as a calm reminder — no engine handoff")
    func taxEducationRoutesToTaxVault() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .taxEducation)
        )
        #expect(result.engineCoverage == .routedToAdvancedTool)
        #expect(result.nextActions == [.reviewInTaxVault])
        #expect(result.primaryHandoff == nil)
    }

    @Test("Investing-education draft routes to Investing Learn as a calm reminder — no engine handoff")
    func investingEducationRoutesToInvestingLearn() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .investingEducation)
        )
        #expect(result.engineCoverage == .routedToAdvancedTool)
        #expect(result.nextActions == [.reviewInInvestingLearn])
        #expect(result.primaryHandoff == nil)
    }

    // MARK: - Other

    @Test("Other draft surfaces a calm noEngineYet note and never produces a handoff")
    func otherDraftHasNoEngineYet() {
        let result = DecisionDraftEvaluator.evaluate(
            draft(kind: .other)
        )
        #expect(result.engineCoverage == .noEngineYet)
        #expect(result.nextActions == [.noEngineYet])
        #expect(result.primaryHandoff == nil)
    }

    // MARK: - No-auto-analysis copy guard

    @Test("Headlines and action labels never use prohibited recommendation / analysis language")
    func evaluatorCopyHasNoProhibitedPhrases() {
        let prohibited: [String] = [
            "analyzed",
            "analysed",
            "best card",
            "best account",
            "best option",
            "recommended",
            "guaranteed",
            "you should",
            "we recommend",
        ]

        let allKinds: [DecisionDraftKind] = [
            .purchase, .creditTiming, .travel,
            .taxEducation, .investingEducation, .other,
        ]
        let snapshots: [DecisionDraftAccountSnapshot] = [
            .empty,
            DecisionDraftAccountSnapshot(hasAnyCreditCard: true),
        ]

        var inspected: [String] = []
        for kind in allKinds {
            for snapshot in snapshots {
                for amount in [Double?.none, 0, 100] {
                    let result = DecisionDraftEvaluator.evaluate(
                        draft(kind: kind, amount: amount),
                        accountSnapshot: snapshot
                    )
                    inspected.append(result.headline)
                    for action in result.nextActions {
                        inspected.append(action.displayLabel)
                        inspected.append(action.accessibilityHint)
                    }
                }
            }
        }

        for phrase in prohibited {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in evaluator copy: \(copy)"
                )
            }
        }
    }

    // MARK: - Determinism

    @Test("Evaluating the same draft twice produces equal output (pure function)")
    func evaluatorIsPure() {
        let purchase = draft(kind: .purchase, amount: 80)
        let snapshot = DecisionDraftAccountSnapshot(hasAnyCreditCard: true)
        let first = DecisionDraftEvaluator.evaluate(purchase, accountSnapshot: snapshot)
        let second = DecisionDraftEvaluator.evaluate(purchase, accountSnapshot: snapshot)
        #expect(first == second)
    }

    @Test("Evaluating a draft does not mutate it (status / fields untouched)")
    func evaluatorDoesNotMutateDraft() {
        let purchase = draft(kind: .purchase, amount: 80, merchant: "Target")
        let originalStatus = purchase.statusRawValue
        let originalMerchant = purchase.merchantName
        let originalAmount = purchase.amount

        _ = DecisionDraftEvaluator.evaluate(purchase)

        #expect(purchase.statusRawValue == originalStatus)
        #expect(purchase.merchantName == originalMerchant)
        #expect(purchase.amount == originalAmount)
        #expect(purchase.status == .needsEngine)
    }
}
