// DecisionDraftIntentTests.swift
// NomadFi
//
// Coverage for Siri / App Shortcut decision-draft intake:
//
//   - `DecisionDraftStore.insertDraft` refuses empty / whitespace
//     scenario text, so voice intake can never create a blank draft.
//   - A valid capture produces exactly one `DecisionDraftRecord`
//     whose status is `.needsEngine`, never analyzed.
//   - Capture does not promote the draft into `DecisionCatalog`.
//   - The intent's `supportedModes` stays `.background` so voice
//     capture never opens the app.
//   - The dialog copy includes the "Needs engine" honesty clause and
//     never uses recommendation language.
//   - The `DecisionDraftKindAppEnum` adapter round-trips every
//     core-model kind.

import AppIntents
import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct DecisionDraftIntentTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DecisionDraftRecord.self,
            Account.self,
            Transaction.self,
            Subscription.self,
            Budget.self,
            ExchangeRate.self,
            JurisdictionProfile.self,
            Currency.self,
            TaxDocument.self,
            ScenarioDecisionRecord.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: - Store helper validation

    @Test("insertDraft rejects a whitespace-only scenario string")
    func insertDraftRejectsWhitespace() throws {
        let context = try makeContext()

        let inserted = DecisionDraftStore.insertDraft(
            scenarioText: "   \n  \t ",
            in: context
        )

        #expect(inserted == nil)
        let fetched = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(fetched.isEmpty)
    }

    @Test("insertDraft trims, stamps timestamps, and creates exactly one record with .needsEngine")
    func insertDraftCreatesSingleNeedsEngineRecord() throws {
        let context = try makeContext()

        let before = Date.now
        let inserted = try #require(
            DecisionDraftStore.insertDraft(
                scenarioText: "  Decide whether to send the Amazon box to the Airbnb or the office.  ",
                title: "  Summer delivery window ",
                kind: .purchase,
                merchantName: " Amazon ",
                locationText: " San Francisco ",
                timingText: " Before arrival ",
                notes: " Host hasn't replied yet. ",
                in: context
            )
        )
        let after = Date.now

        #expect(inserted.status == .needsEngine)
        #expect(inserted.scenarioText == "Decide whether to send the Amazon box to the Airbnb or the office.")
        #expect(inserted.title == "Summer delivery window")
        #expect(inserted.merchantName == "Amazon")
        #expect(inserted.locationText == "San Francisco")
        #expect(inserted.timingText == "Before arrival")
        #expect(inserted.notes == "Host hasn't replied yet.")
        #expect(inserted.createdAt >= before && inserted.createdAt <= after)
        #expect(inserted.updatedAt == inserted.createdAt)

        let fetched = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(fetched.count == 1)
    }

    @Test("insertDraft keeps drafts outside DecisionCatalog — no analyzed decision is created")
    func insertDraftDoesNotEnterCatalog() throws {
        let context = try makeContext()
        let inserted = try #require(
            DecisionDraftStore.insertDraft(
                scenarioText: "Considering TFSA vs. RRSP for next year.",
                kind: .taxEducation,
                in: context
            )
        )

        let catalogIDs = Set(DecisionCatalog.all.map(\.id.rawValue))
        #expect(!catalogIDs.contains(inserted.draftID.uuidString))
        #expect(DecisionCatalog.all.map(\.id) == [.amazonArrivalOrder, .creditTimingCheck])
    }

    // MARK: - Intent mode

    @Test("CaptureDecisionDraftIntent runs in background — never opens the app")
    func captureIntentIsBackground() {
        let modes = CaptureDecisionDraftIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    // MARK: - Dialog copy

    @Test("draftCaptureSuccess dialog marks the draft Needs engine")
    func captureSuccessDialogMentionsNeedsEngine() {
        let dialog = DecisionAssistantIntentDialog.draftCaptureSuccess(
            title: "Summer laptop"
        )
        #expect(dialog.contains("Needs engine"))
        #expect(dialog.contains("decision draft"))
        #expect(dialog.contains("Summer laptop"))
    }

    @Test("draftCaptureSuccess dialog avoids every prohibited recommendation phrase")
    func captureSuccessDialogHasNoRecommendationLanguage() {
        let variants = [
            DecisionAssistantIntentDialog.draftCaptureSuccess(title: ""),
            DecisionAssistantIntentDialog.draftCaptureSuccess(title: "Summer laptop"),
        ]
        let prohibited = [
            "analyzed",
            "analysed",
            "recommended",
            "recommend this",
            "best card",
            "lowest fee",
            "verified",
        ]
        for dialog in variants {
            let lowered = dialog.lowercased()
            for phrase in prohibited {
                #expect(
                    !lowered.contains(phrase),
                    "Capture-success dialog must not contain the phrase \"\(phrase)\": \(dialog)"
                )
            }
        }
    }

    @Test("draftCaptureMissingScenario dialog asks for a description without claiming analysis")
    func missingScenarioDialogIsHonest() {
        let dialog = DecisionAssistantIntentDialog.draftCaptureMissingScenario
        #expect(dialog.localizedStandardContains("description"))
        let lowered = dialog.lowercased()
        #expect(!lowered.contains("analyzed"))
        #expect(!lowered.contains("recommend"))
    }

    // MARK: - Kind adapter

    @Test("DecisionDraftKindAppEnum round-trips every DecisionDraftKind case")
    func kindAdapterRoundTripsAllCases() {
        for core in DecisionDraftKind.allCases {
            let adapter = DecisionDraftKindAppEnum(core)
            #expect(adapter.draftKind == core)
        }
    }

    @Test("DecisionDraftKindAppEnum exposes a display representation for every case")
    func kindAdapterHasDisplayForEveryCase() {
        for adapter in DecisionDraftKindAppEnum.allCases {
            #expect(
                DecisionDraftKindAppEnum.caseDisplayRepresentations[adapter] != nil,
                "Missing DisplayRepresentation for \(adapter)"
            )
        }
    }
}
