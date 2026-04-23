// DecisionDraftRecordTests.swift
// NomadFi
//
// Coverage for Decision Draft Intake v1:
//
//   - Default status is `.needsEngine` (NomadFi never auto-analyzes).
//   - The capture form refuses to save when the scenario body is
//     empty after trimming.
//   - Save trims every textual field, parses the amount, stamps
//     `createdAt`/`updatedAt`, and inserts a real SwiftData record.
//   - Records round-trip through an in-memory container with the
//     typed `kind`, `status`, and `currencyCode` projections intact.
//   - `DataGovernancePolicy.deleteAllUserData` wipes drafts.
//   - Drafts are not promoted into `DecisionCatalog` — they remain
//     raw user context, not analyzed decisions.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

/// SwiftData model-container tests are serialized to avoid a Swift
/// Testing / SwiftData parallel-init race: the test host aborts with
/// `SIGABRT` when multiple `ModelContainer(…)` calls happen concurrently
/// inside a single suite under the simulator's Main Thread Checker +
/// `SQLITE_ENABLE_THREAD_ASSERTIONS` env. Production logic is not
/// stateful — only the test harness needs this trait.
@MainActor
@Suite(.serialized)
struct DecisionDraftRecordTests {

    // MARK: - Helpers

    /// Routes through ``SwiftDataTestContainerFactory`` so every
    /// `@Model` that `DataGovernancePolicy.deleteAllUserData` wipes is
    /// registered. Adding a future `@Model` type is a one-file edit
    /// in the factory; this suite stays green without further churn.
    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    // MARK: - Defaults

    @Test("Fresh record defaults to needs-engine status")
    func freshRecordIsNeedsEngine() {
        let record = DecisionDraftRecord()
        #expect(record.status == .needsEngine)
        #expect(record.statusRawValue == DecisionDraftStatus.needsEngine.rawValue)
    }

    @Test("Fresh record defaults to purchase kind and USD currency")
    func freshRecordDefaultsAreSensible() {
        let record = DecisionDraftRecord()
        #expect(record.kind == .purchase)
        #expect(record.currencyCode == .usd)
        #expect(record.amount == nil)
    }

    @Test("DecisionDraftKind exposes a non-empty label, symbol, and accessibility label for every case")
    func kindLabelsAreExhaustive() {
        for kind in DecisionDraftKind.allCases {
            #expect(!kind.displayLabel.isEmpty)
            #expect(!kind.systemImage.isEmpty)
            #expect(!kind.accessibilityLabel.isEmpty)
        }
    }

    @Test("DecisionDraftStatus exposes a non-empty label, symbol, and accessibility label for every case")
    func statusLabelsAreExhaustive() {
        for status in DecisionDraftStatus.allCases {
            #expect(!status.displayLabel.isEmpty)
            #expect(!status.systemImage.isEmpty)
            #expect(!status.accessibilityLabel.isEmpty)
        }
    }

    // MARK: - Form validation

    @Test("Form refuses to save when scenario text is empty")
    func emptyScenarioBlocksSave() throws {
        let context = try makeContext()
        let vm = DecisionDraftFormViewModel()
        #expect(!vm.canSave)
        #expect(vm.save(into: context) == nil)
    }

    @Test("Form refuses to save when scenario text is only whitespace")
    func whitespaceOnlyScenarioBlocksSave() throws {
        let context = try makeContext()
        let vm = DecisionDraftFormViewModel()
        vm.scenarioText = "   \n  "
        #expect(!vm.canSave)
        #expect(vm.save(into: context) == nil)
    }

    // MARK: - Save behavior

    @Test("Save trims every textual field, parses amount, and stamps timestamps")
    func saveTrimsAndStampsTimestamps() throws {
        let context = try makeContext()
        let vm = DecisionDraftFormViewModel()
        vm.title = "  Summer laptop  "
        vm.scenarioText = "  Deciding between Amazon ACC and Wise USD.  \n"
        vm.kind = .purchase
        vm.merchantName = "  Amazon "
        vm.locationText = " San Francisco "
        vm.timingText = " Before arrival "
        vm.notes = " Arrival timing matters. "
        vm.amountText = " 1899.99 "
        vm.currencyCode = .usd

        let before = Date.now
        let saved = try #require(vm.save(into: context))
        let after = Date.now

        #expect(saved.title == "Summer laptop")
        #expect(saved.scenarioText == "Deciding between Amazon ACC and Wise USD.")
        #expect(saved.merchantName == "Amazon")
        #expect(saved.locationText == "San Francisco")
        #expect(saved.timingText == "Before arrival")
        #expect(saved.notes == "Arrival timing matters.")
        #expect(saved.amount == 1899.99)
        #expect(saved.currencyCode == .usd)
        #expect(saved.status == .needsEngine)

        #expect(saved.createdAt >= before && saved.createdAt <= after)
        #expect(saved.updatedAt == saved.createdAt)
    }

    @Test("Blank amount field persists as nil, not zero")
    func blankAmountIsNil() throws {
        let context = try makeContext()
        let vm = DecisionDraftFormViewModel()
        vm.scenarioText = "A tax-residency question."
        vm.kind = .taxEducation
        vm.amountText = ""

        let saved = try #require(vm.save(into: context))
        #expect(saved.amount == nil)
    }

    // MARK: - Round-trip

    @Test("Record round-trips through an in-memory SwiftData container")
    func recordRoundTripsThroughContext() throws {
        let context = try makeContext()
        let draftID = UUID()
        let record = DecisionDraftRecord(
            draftID: draftID,
            title: "Weekend trip",
            scenarioText: "Wondering which card for Toronto groceries.",
            kind: .travel,
            merchantName: "Loblaws",
            locationText: "Toronto",
            amount: 80,
            currencyCode: .cad,
            timingText: "This weekend",
            notes: "Weekend meal prep run."
        )
        context.insert(record)
        try context.save()

        var descriptor = FetchDescriptor<DecisionDraftRecord>(
            predicate: #Predicate { $0.draftID == draftID }
        )
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)

        #expect(fetched.title == "Weekend trip")
        #expect(fetched.scenarioText == "Wondering which card for Toronto groceries.")
        #expect(fetched.kind == .travel)
        #expect(fetched.merchantName == "Loblaws")
        #expect(fetched.locationText == "Toronto")
        #expect(fetched.amount == 80)
        #expect(fetched.currencyCode == .cad)
        #expect(fetched.timingText == "This weekend")
        #expect(fetched.notes == "Weekend meal prep run.")
        #expect(fetched.status == .needsEngine)
    }

    @Test("Unknown raw values fall back to safe defaults instead of crashing")
    func unknownRawValuesFallBackSafely() {
        let record = DecisionDraftRecord()
        record.kindRawValue = "not-a-kind"
        record.statusRawValue = "unknown"
        record.currencyCodeRawValue = "XXX"

        #expect(record.kind == .other)
        #expect(record.status == .needsEngine)
        #expect(record.currencyCode == .usd)
    }

    // MARK: - Display

    @Test("displayTitle falls back to the first scenario line when title is empty")
    func displayTitleFallback() {
        let record = DecisionDraftRecord(
            title: "",
            scenarioText: "Moving to San Francisco.\nAsking about rent timing."
        )
        #expect(record.displayTitle == "Moving to San Francisco.")
    }

    @Test("displayTitle falls back to Untitled draft when both title and scenario are blank")
    func displayTitleUntitledFallback() {
        let record = DecisionDraftRecord(title: "", scenarioText: "")
        #expect(record.displayTitle == "Untitled draft")
    }

    // MARK: - Data governance

    @Test("DecisionCatalog never promotes a captured draft into an analyzed decision")
    func draftsAreNotPromotedIntoTheCatalog() {
        // The catalog is the source of truth for decisions with a
        // deterministic engine. Drafts deliberately live outside it.
        let catalogIDs = Set(DecisionCatalog.all.map(\.id.rawValue))
        #expect(!catalogIDs.contains("decision-draft"))
        for kind in DecisionDraftKind.allCases {
            #expect(!catalogIDs.contains(kind.rawValue))
        }
    }

    @Test("deleteAllUserData removes every captured draft")
    func deleteAllUserDataRemovesDrafts() throws {
        let context = try makeContext()

        // Seed multiple drafts so the wipe has something real to do.
        for index in 0..<3 {
            let record = DecisionDraftRecord(
                scenarioText: "Draft \(index)",
                kind: .other
            )
            context.insert(record)
        }
        try context.save()

        let before = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(before.count == 3)

        let notificationManager = NotificationManager()
        DataGovernancePolicy.deleteAllUserData(
            in: context,
            notificationManager: notificationManager
        )

        let after = try context.fetch(FetchDescriptor<DecisionDraftRecord>())
        #expect(after.isEmpty)
    }
}
