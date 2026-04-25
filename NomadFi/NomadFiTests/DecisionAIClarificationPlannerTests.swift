// DecisionAIClarificationPlannerTests.swift
// NomadFi
//
// Pins the contract of `DecisionAIClarificationPlanner`:
//
//   • Bounded — the plan never exceeds
//     `DecisionAIClarificationPlan.maxQuestions`.
//   • Kind-aware — non-purchase kinds never produce
//     purchase-shaped questions even when the supplied "missing"
//     list mentions them.
//   • Deterministic — same input always produces the same plan.
//   • Ordered — questions follow
//     `DecisionDraftInterpretationMissingField.allCases`.
//   • Copy-safe — every prompt and helper string is checked for
//     prohibited recommendation language.

import Foundation
import Testing

@testable import NomadFi

struct DecisionAIClarificationPlannerTests {

    // MARK: - Bounded

    @Test("Plan is capped at DecisionAIClarificationPlan.maxQuestions even when more required fields are missing")
    func planIsCappedAtMaxQuestions() {
        // Purchase only has two required fields today (amount,
        // currency) — to exercise the cap honestly we synthesise
        // the worst case by handing every possible missing field
        // to the planner. The planner's intersect-with-required
        // logic still bounds the result.
        let everyField = DecisionDraftInterpretationMissingField.allCases
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: everyField
        )
        #expect(plan.count <= DecisionAIClarificationPlan.maxQuestions)
    }

    // MARK: - Kind-aware

    @Test("Purchase missing amount + currency yields exactly two questions about those fields")
    func purchasePlanAsksAboutAmountAndCurrency() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: [.amount, .currencyCode]
        )
        #expect(plan.count == 2)
        #expect(plan.questions.map(\.field) == [.amount, .currencyCode])
    }

    @Test("Travel uses the same purchase-shaped completeness rules")
    func travelPlanMirrorsPurchase() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .travel,
            missingFields: [.amount, .currencyCode]
        )
        #expect(plan.questions.map(\.field) == [.amount, .currencyCode])
    }

    @Test("Credit Timing never asks irrelevant merchant/amount/currency questions")
    func creditTimingPlanIsEmpty() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .creditTiming,
            missingFields: [.amount, .currencyCode, .merchantName, .locationText]
        )
        #expect(plan.isEmpty)
    }

    @Test("Tax Education never asks purchase-shaped questions")
    func taxEducationPlanIsEmpty() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .taxEducation,
            missingFields: [.amount, .currencyCode, .merchantName]
        )
        #expect(plan.isEmpty)
    }

    @Test("Investing Education never asks purchase-shaped questions")
    func investingEducationPlanIsEmpty() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .investingEducation,
            missingFields: [.amount, .currencyCode, .merchantName]
        )
        #expect(plan.isEmpty)
    }

    @Test("`other` stays conservative — never asks anything")
    func otherPlanIsEmpty() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .other,
            missingFields: [.amount, .currencyCode, .merchantName, .locationText, .timingText]
        )
        #expect(plan.isEmpty)
    }

    // MARK: - Ordering + idempotence

    @Test("Plan ordering matches DecisionDraftInterpretationMissingField.allCases regardless of input order")
    func planOrderIsStableRegardlessOfInputOrder() {
        let forward = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: [.amount, .currencyCode]
        )
        let reversed = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: [.currencyCode, .amount]
        )
        #expect(forward == reversed)
        #expect(forward.questions.map(\.field) == [.amount, .currencyCode])
    }

    @Test("Same input always produces the same plan (pure function)")
    func planIsDeterministic() {
        let inputs: [DecisionDraftInterpretationMissingField] = [.amount, .currencyCode]
        let first = DecisionAIClarificationPlanner.plan(kind: .purchase, missingFields: inputs)
        let second = DecisionAIClarificationPlanner.plan(kind: .purchase, missingFields: inputs)
        #expect(first == second)
    }

    @Test("Empty missing-field input yields the empty plan even on a kind that has required fields")
    func emptyMissingYieldsEmptyPlan() {
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: []
        )
        #expect(plan.isEmpty)
    }

    @Test("Missing fields that are not required for the kind are ignored")
    func unrelatedMissingFieldsAreIgnored() {
        // Purchase doesn't require merchant — handing it as
        // "missing" should not produce a question about it.
        let plan = DecisionAIClarificationPlanner.plan(
            kind: .purchase,
            missingFields: [.merchantName, .timingText, .title]
        )
        #expect(plan.isEmpty)
    }

    // MARK: - Copy guard

    @Test("Clarifying-question copy never uses prohibited recommendation / verified / analyzed language")
    func copyGuardOnAllPossibleQuestions() {
        let prohibited: [String] = [
            "best card",
            "best account",
            "best option",
            "recommended",
            "we recommend",
            "you should",
            "analyzed",
            "analysed",
            "verified rewards",
            "guaranteed",
        ]

        // Generate every possible question by asking the planner
        // for each field in turn under purchase (which has the
        // widest required set in the value layer).
        let fields = DecisionDraftInterpretationMissingField.allCases
        for field in fields {
            let plan = DecisionAIClarificationPlanner.plan(
                kind: .purchase,
                missingFields: [field]
            )
            for question in plan.questions {
                for phrase in prohibited {
                    #expect(
                        !question.prompt.localizedStandardContains(phrase),
                        "Banned phrase '\(phrase)' in prompt for \(question.field): \(question.prompt)"
                    )
                    if let helper = question.helper {
                        #expect(
                            !helper.localizedStandardContains(phrase),
                            "Banned phrase '\(phrase)' in helper for \(question.field): \(helper)"
                        )
                    }
                }
            }
        }
    }
}
