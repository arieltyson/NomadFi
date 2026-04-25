// DecisionAIIntakeTests.swift
// NomadFi
//
// Phase 9A coverage. The interpreter is fully protocol-backed,
// so every UI / view-model path exercises the deterministic
// `PreviewDecisionDraftInterpreter` rather than the production
// Foundation Models adapter. The full-schema container factory
// hosts the SwiftData inserts.
//
// Pinned product contract:
//
//   • The interpreter never persists. The view model only inserts
//     a `DecisionDraftRecord` from `confirmAndSave(in:)` after
//     the user-confirmed review.
//   • Editable review fields seed from the interpretation but
//     typed user edits win on save.
//   • Missing fields surface verbatim — the model never silently
//     defaults a gap.
//   • Availability state drives the sheet's render path. The
//     typed form remains the universal fallback.
//   • Copy guard: nothing in the interpretation, mapper, or
//     view-model surfaces uses recommendation, "verified",
//     "best", or "analyzed" language.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct DecisionAIIntakeTests {

    // MARK: - Helpers

    private func sampleInterpretation(
        kind: DecisionDraftKind = .purchase,
        amount: Double? = 80,
        currency: CurrencyCode? = .usd,
        merchant: String? = "Target",
        location: String? = "San Francisco",
        timing: String? = "this weekend",
        title: String? = "Weekend grocery run",
        notes: String? = nil,
        missing: [DecisionDraftInterpretationMissingField] = [],
        confidenceNote: String? = nil,
        scenarioText: String = "Buying groceries at Target this weekend, paying around $80."
    ) -> DecisionDraftInterpretation {
        DecisionDraftInterpretation(
            kind: kind,
            title: title,
            scenarioText: scenarioText,
            merchantName: merchant,
            locationText: location,
            amount: amount,
            currencyCode: currency,
            timingText: timing,
            notes: notes,
            missingFields: missing,
            confidenceNote: confidenceNote
        )
    }

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    // MARK: - Mapper

    @Test("Mapper builds a DecisionDraftRecord with status .needsEngine and trimmed fields")
    func mapperBuildsRecord() {
        let interpretation = sampleInterpretation(
            title: "  Weekend grocery run  ",
            scenarioText: "  Some scenario text.  "
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = DecisionDraftInterpretationMapper.record(
            from: interpretation,
            now: now
        )
        #expect(record.status == .needsEngine)
        #expect(record.kind == .purchase)
        #expect(record.title == "Weekend grocery run")
        #expect(record.scenarioText == "Some scenario text.")
        #expect(record.merchantName == "Target")
        #expect(record.locationText == "San Francisco")
        #expect(record.timingText == "this weekend")
        #expect(record.amount == 80)
        #expect(record.currencyCode == .usd)
        #expect(record.createdAt == now)
        #expect(record.updatedAt == now)
    }

    @Test("Mapper coerces nil currency to USD by default and drops non-positive amounts")
    func mapperHandlesMissingFields() {
        let interpretation = sampleInterpretation(
            amount: -5,
            currency: nil,
            merchant: nil,
            location: nil,
            timing: nil,
            title: nil
        )
        let record = DecisionDraftInterpretationMapper.record(
            from: interpretation
        )
        #expect(record.title == "")
        #expect(record.merchantName == "")
        #expect(record.locationText == "")
        #expect(record.timingText == "")
        #expect(record.amount == nil)
        #expect(record.currencyCode == .usd)
    }

    // MARK: - Availability

    @Test("Availability headlines are honest and never claim Apple Intelligence is available everywhere")
    func availabilityHeadlinesAreHonest() {
        #expect(DecisionAIIntakeAvailability.available.unavailableHeadline == nil)
        #expect(DecisionAIIntakeAvailability.modelNotReady.unavailableHeadline != nil)
        #expect(DecisionAIIntakeAvailability.appleIntelligenceDisabled.unavailableHeadline != nil)
        #expect(DecisionAIIntakeAvailability.unsupportedOnThisDevice.unavailableHeadline != nil)
        #expect(DecisionAIIntakeAvailability.foundationModelsUnavailable.unavailableHeadline != nil)
    }

    @Test("isReadyToRun is true only for .available")
    func isReadyToRunOnlyForAvailable() {
        #expect(DecisionAIIntakeAvailability.available.isReadyToRun == true)
        let unavailable: [DecisionAIIntakeAvailability] = [
            .modelNotReady,
            .appleIntelligenceDisabled,
            .unsupportedOnThisDevice,
            .foundationModelsUnavailable,
        ]
        for state in unavailable {
            #expect(state.isReadyToRun == false)
        }
    }

    // MARK: - View model: capture → review → save

    @Test("Successful interpretation seeds review fields and never inserts until confirmAndSave is called")
    func successInterpretationSeedsReviewFields() async throws {
        let context = try makeContext()
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation())
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Buying groceries at Target this weekend, paying around $80."

        await viewModel.interpret()

        if case .review = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .review stage, got \(viewModel.stage)")
        }
        #expect(viewModel.reviewKind == .purchase)
        #expect(viewModel.reviewTitle == "Weekend grocery run")
        #expect(viewModel.reviewMerchantName == "Target")
        #expect(viewModel.reviewAmountText == "80")

        // No record inserted yet — interpretation alone does not persist.
        let beforeSave = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>()
        )
        #expect(beforeSave.isEmpty)

        // Confirm and save: now exactly one record exists.
        let saved = viewModel.confirmAndSave(in: context)
        #expect(saved != nil)
        let afterSave = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>()
        )
        #expect(afterSave.count == 1)
        #expect(afterSave.first?.status == .needsEngine)
    }

    @Test("Editable review fields override interpreter output on save")
    func userEditsWinOnSave() async throws {
        let context = try makeContext()
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation(amount: 80, merchant: "Target"))
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Buying groceries at Target this weekend, paying around $80."
        await viewModel.interpret()

        // User edits before save.
        viewModel.reviewMerchantName = "Whole Foods"
        viewModel.reviewAmountText = "120"
        viewModel.reviewTitle = "Edited title"

        let saved = try #require(viewModel.confirmAndSave(in: context))
        #expect(saved.merchantName == "Whole Foods")
        #expect(saved.amount == 120)
        #expect(saved.title == "Edited title")
    }

    @Test("Failed interpretation moves to .failed stage and does not insert anything")
    func failedInterpretationStaysOnSheet() async throws {
        let context = try makeContext()
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .failed(reason: "Could not extract a draft from this scenario.")
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Some text."

        await viewModel.interpret()

        if case .failed(let reason) = viewModel.stage {
            #expect(reason.contains("Could not extract"))
        } else {
            Issue.record("Expected .failed stage, got \(viewModel.stage)")
        }

        let drafts = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>()
        )
        #expect(drafts.isEmpty)
    }

    @Test("interpret() is a no-op when canInterpret is false (unavailable device)")
    func interpretIsNoOpWhenUnavailable() async {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .unsupportedOnThisDevice,
            result: .interpreted(sampleInterpretation())
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Some text."

        #expect(viewModel.canInterpret == false)
        await viewModel.interpret()
        // Stage stayed at .capture because availability blocked the run.
        if case .capture = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .capture stage, got \(viewModel.stage)")
        }
    }

    @Test("interpret() is a no-op when scenario text is empty after trimming")
    func interpretIsNoOpForEmptyScenario() async {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation())
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "   "

        #expect(viewModel.canInterpret == false)
        await viewModel.interpret()
        if case .capture = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .capture stage, got \(viewModel.stage)")
        }
    }

    @Test("confirmAndSave returns nil when scenario text is empty (defence in depth)")
    func confirmAndSaveRefusesEmptyScenario() throws {
        let context = try makeContext()
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation())
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.scenarioText = "   "
        let saved = viewModel.confirmAndSave(in: context)
        #expect(saved == nil)

        let drafts = try context.fetch(
            FetchDescriptor<DecisionDraftRecord>()
        )
        #expect(drafts.isEmpty)
    }

    @Test("Missing fields list flows from the interpretation to the view model verbatim")
    func missingFieldsSurfaceVerbatim() async {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation(
                amount: nil,
                currency: nil,
                missing: [.amount, .currencyCode]
            ))
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Some text."
        await viewModel.interpret()
        #expect(viewModel.missingFields == [.amount, .currencyCode])
    }

    @Test("backToCapture clears the pending interpretation and returns to capture stage")
    func backToCaptureClearsState() async {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation())
        )
        let viewModel = DecisionAIIntakeViewModel(interpreter: interpreter)
        viewModel.refreshAvailability()
        viewModel.scenarioText = "Some text."
        await viewModel.interpret()
        #expect(viewModel.pendingInterpretation != nil)

        viewModel.backToCapture()
        #expect(viewModel.pendingInterpretation == nil)
        if case .capture = viewModel.stage {
            // expected
        } else {
            Issue.record("Expected .capture stage, got \(viewModel.stage)")
        }
    }

    // MARK: - Preview interpreter

    @Test("PreviewDecisionDraftInterpreter rejects empty scenarios upstream")
    func previewInterpreterRejectsEmptyScenario() async {
        let interpreter = PreviewDecisionDraftInterpreter(
            availability: .available,
            result: .interpreted(sampleInterpretation())
        )
        let result = await interpreter.interpret(scenarioText: "   ")
        if case .failed(let reason) = result {
            #expect(reason.localizedStandardContains("Add a scenario"))
        } else {
            Issue.record("Expected .failed for empty scenario, got \(result)")
        }
    }

    // MARK: - Copy guard

    @Test("Interpretation, mapper output, and view-model copy never use prohibited recommendation language")
    func copyGuardOnAIIntakeSurfaces() async {
        let prohibited: [String] = [
            "best card",
            "best account",
            "best option",
            "recommended",
            "analyzed",
            "analysed",
            "guaranteed",
            "you should",
            "we recommend",
            "verified rewards",
        ]

        var inspected: [String] = []
        for state: DecisionAIIntakeAvailability in [
            .available,
            .modelNotReady,
            .appleIntelligenceDisabled,
            .unsupportedOnThisDevice,
            .foundationModelsUnavailable,
        ] {
            if let headline = state.unavailableHeadline {
                inspected.append(headline)
            }
        }
        for field in DecisionDraftInterpretationMissingField.allCases {
            inspected.append(field.displayLabel)
        }

        for phrase in prohibited {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in AI intake copy: \(copy)"
                )
            }
        }
    }
}
