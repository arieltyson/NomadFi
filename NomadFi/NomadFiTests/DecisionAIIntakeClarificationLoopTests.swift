// DecisionAIIntakeClarificationLoopTests.swift
// NomadFi
//
// Pins the bounded clarifying-question loop on
// `DecisionAIIntakeViewModel`:
//
//   • After a successful interpretation that leaves required
//     fields empty, the view model enters `.clarifying`, not
//     `.review`.
//   • Each submitted answer folds into the pending interpretation
//     and seeds the corresponding review-form field.
//   • The loop is bounded — when the plan is exhausted (or skipped
//     entirely) the view model transitions to `.review`.
//   • Save still requires explicit confirmation; nothing is
//     persisted automatically by the loop.
//   • Non-purchase kinds short-circuit straight to `.review` even
//     when amount/currency are missing — kind-aware contract.
//   • Typed-form fallback remains reachable from every loop state.
//
// Existing `DecisionAIIntakeTests` cover the happy path; this
// suite focuses specifically on the new follow-through.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct DecisionAIIntakeClarificationLoopTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func purchaseInterpretation(
        amount: Double? = nil,
        currency: CurrencyCode? = nil,
        scenarioText: String = "Trying to figure out which card to use for an order."
    ) -> DecisionDraftInterpretation {
        DecisionDraftInterpretation(
            kind: .purchase,
            title: nil,
            scenarioText: scenarioText,
            merchantName: nil,
            locationText: nil,
            amount: amount,
            currencyCode: currency,
            timingText: nil,
            notes: nil,
            missingFields: [],
            confidenceNote: nil
        )
    }

    private func educationInterpretation() -> DecisionDraftInterpretation {
        DecisionDraftInterpretation(
            kind: .taxEducation,
            title: nil,
            scenarioText: "Need to understand which forms apply to my U.S. internship.",
            merchantName: nil,
            locationText: nil,
            amount: nil,
            currencyCode: nil,
            timingText: nil,
            notes: nil,
            missingFields: [],
            confidenceNote: nil
        )
    }

    private func makeViewModel(
        result: DecisionAIIntakeResult
    ) -> DecisionAIIntakeViewModel {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: result
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "A scenario."
        return viewModel
    }

    // MARK: - Routing into .clarifying

    @Test("Purchase interpretation missing amount + currency enters .clarifying after interpret(), not .review")
    func purchaseMissingFieldsEntersClarifying() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()

        guard case .clarifying(let index) = viewModel.stage else {
            Issue.record("Expected .clarifying, got \(viewModel.stage)")
            return
        }
        #expect(index == 0)
        #expect(!viewModel.clarificationPlan.isEmpty)
        #expect(viewModel.clarificationPlan.count == 2)
    }

    @Test("Purchase interpretation with amount + currency present skips clarification and lands on .review")
    func purchaseFullyPopulatedSkipsClarification() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation(amount: 80, currency: .usd))
        )
        await viewModel.interpret()
        if case .review = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .review, got \(viewModel.stage)")
        }
        #expect(viewModel.clarificationPlan.isEmpty)
    }

    @Test("Tax-education interpretation always skips clarification — never asks purchase-shaped questions")
    func taxEducationAlwaysSkipsClarification() async {
        let viewModel = makeViewModel(
            result: .interpreted(educationInterpretation())
        )
        await viewModel.interpret()
        if case .review = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .review for taxEducation, got \(viewModel.stage)")
        }
        #expect(viewModel.clarificationPlan.isEmpty)
    }

    // MARK: - Bounded loop

    @Test("Submitting an amount answer folds into the interpretation, seeds the review field, and advances")
    func submittingAmountAdvancesAndSeedsReview() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        // First question is amount per ordering.
        #expect(viewModel.currentClarifyingQuestion?.field == .amount)

        viewModel.clarificationDraftText = "199.50"
        viewModel.submitClarificationAnswer()

        // Advanced to currency question.
        guard case .clarifying(let index) = viewModel.stage else {
            Issue.record("Expected .clarifying after submit, got \(viewModel.stage)")
            return
        }
        #expect(index == 1)
        #expect(viewModel.currentClarifyingQuestion?.field == .currencyCode)
        #expect(viewModel.pendingInterpretation?.amount == 199.50)
        #expect(viewModel.reviewAmountText == "199.5")
    }

    @Test("Submitting both questions exits the loop and lands on .review")
    func submittingFullPlanLandsOnReview() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()

        viewModel.clarificationDraftText = "100"
        viewModel.submitClarificationAnswer()

        // Currency question. Default draft currency seeded from
        // pending interpretation; force a deliberate USD pick.
        viewModel.clarificationDraftCurrency = .usd
        viewModel.submitClarificationAnswer()

        if case .review = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .review after exhausting plan, got \(viewModel.stage)")
        }
        #expect(viewModel.pendingInterpretation?.amount == 100)
        #expect(viewModel.pendingInterpretation?.currencyCode == .usd)
        #expect(viewModel.reviewCurrencyCode == .usd)
    }

    @Test("Skip current question advances without folding any answer into the interpretation")
    func skipCurrentAdvancesWithoutAnswer() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        viewModel.skipCurrentClarification()

        guard case .clarifying(let index) = viewModel.stage else {
            Issue.record("Expected .clarifying after skip, got \(viewModel.stage)")
            return
        }
        #expect(index == 1)
        #expect(viewModel.pendingInterpretation?.amount == nil)
    }

    @Test("Skip-all jumps straight to .review and keeps the user in control")
    func skipAllJumpsToReview() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        viewModel.skipAllClarification()

        if case .review = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .review after skip-all, got \(viewModel.stage)")
        }
        // Pending interpretation untouched.
        #expect(viewModel.pendingInterpretation?.amount == nil)
        #expect(viewModel.pendingInterpretation?.currencyCode == nil)
    }

    // MARK: - Save semantics

    @Test("Persistence still requires explicit confirmAndSave — neither interpret nor the loop ever inserts a record")
    func loopDoesNotPersistImplicitly() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        viewModel.clarificationDraftText = "50"
        viewModel.submitClarificationAnswer()
        viewModel.clarificationDraftCurrency = .usd
        viewModel.submitClarificationAnswer()

        let beforeSave = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(beforeSave.isEmpty)

        let saved = viewModel.confirmAndSave(in: context)
        #expect(saved != nil)
        let afterSave = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(afterSave.count == 1)
    }

    // MARK: - Submit-button gating

    @Test("canSubmitClarificationAnswer is false on a text question with empty draft, true once filled")
    func submitGateRequiresNonEmptyText() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        // Amount is the first question — text-based input.
        #expect(viewModel.canSubmitClarificationAnswer == false)
        viewModel.clarificationDraftText = "12"
        #expect(viewModel.canSubmitClarificationAnswer == true)
    }

    @Test("canSubmitClarificationAnswer is true for picker questions even before the user touches the picker")
    func submitGateAllowsPickerWithoutEdit() async {
        // Step past the amount question to land on currency
        // (which uses a picker).
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation(amount: 80))
        )
        await viewModel.interpret()
        // Plan now has only currency question.
        #expect(viewModel.currentClarifyingQuestion?.field == .currencyCode)
        #expect(viewModel.canSubmitClarificationAnswer == true)
    }

    // MARK: - Reset

    @Test("Reset clears clarification state along with everything else")
    func resetClearsClarificationState() async {
        let viewModel = makeViewModel(
            result: .interpreted(purchaseInterpretation())
        )
        await viewModel.interpret()
        viewModel.clarificationDraftText = "55"
        viewModel.reset()

        if case .capture = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .capture after reset, got \(viewModel.stage)")
        }
        #expect(viewModel.clarificationPlan.isEmpty)
        #expect(viewModel.clarificationDraftText.isEmpty)
        #expect(viewModel.pendingInterpretation == nil)
    }

    // MARK: - Missing-fields exposure

    @Test("missingFields surfaces the kind-aware completeness list, not the interpreter's raw property")
    func missingFieldsUsesCompletenessEvaluator() async {
        // Build an interpretation with a *populated* missingFields
        // property that lies — claims `title` is missing. The view
        // model should ignore that and report only kind-required
        // gaps (purchase: amount + currency).
        let lying = DecisionDraftInterpretation(
            kind: .purchase,
            title: "Has a title",
            scenarioText: "S.",
            merchantName: nil,
            locationText: nil,
            amount: nil,
            currencyCode: nil,
            timingText: nil,
            notes: nil,
            missingFields: [.title, .timingText],
            confidenceNote: nil
        )
        let viewModel = makeViewModel(result: .interpreted(lying))
        await viewModel.interpret()
        #expect(viewModel.missingFields == [.amount, .currencyCode])
    }
}
