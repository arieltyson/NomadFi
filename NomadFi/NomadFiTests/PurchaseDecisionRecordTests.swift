// PurchaseDecisionRecordTests.swift
// NomadFi
//
// Coverage for the generic purchase-decision SwiftData record:
//
//   - Defaults are CloudKit-safe (every field has a value).
//   - `fetchOrCreateActiveRecord` is idempotent — returns the same
//     row across calls on the same context.
//   - Round-trip through an in-memory container preserves inputs.
//   - `DataGovernancePolicy.deleteAllUserData` wipes records.
//   - `hasUsableContext` mirrors the engine's amount requirement.
//   - Unknown raw values fall back to safe defaults.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct PurchaseDecisionRecordTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PurchaseDecisionRecord.self,
            Account.self,
            Transaction.self,
            Subscription.self,
            Budget.self,
            ExchangeRate.self,
            JurisdictionProfile.self,
            Currency.self,
            TaxDocument.self,
            ScenarioDecisionRecord.self,
            DecisionDraftRecord.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: - Defaults

    @Test("Fresh record defaults to general category, USD, nil amount")
    func freshRecordDefaults() {
        let record = PurchaseDecisionRecord()
        #expect(record.category == .general)
        #expect(record.currencyCode == .usd)
        #expect(record.amount == nil)
        #expect(record.merchantName.isEmpty)
        #expect(record.countryCode.isEmpty)
        #expect(record.timingText.isEmpty)
    }

    @Test("Unknown raw values fall back to general category and USD currency")
    func unknownRawValuesFallBackSafely() {
        let record = PurchaseDecisionRecord()
        record.categoryRawValue = "not-a-category"
        record.currencyCodeRawValue = "XXX"
        #expect(record.category == .general)
        #expect(record.currencyCode == .usd)
    }

    @Test("hasUsableContext follows the engine's amount requirement")
    func hasUsableContextFollowsAmount() {
        let record = PurchaseDecisionRecord()
        #expect(!record.hasUsableContext)

        record.amount = 0
        #expect(!record.hasUsableContext)

        record.amount = 25
        #expect(record.hasUsableContext)
    }

    // MARK: - Bootstrap idempotency

    @Test("fetchOrCreateActiveRecord returns the same row across calls")
    func fetchOrCreateIsIdempotent() throws {
        let context = try makeContext()
        let first = PurchaseDecisionRecord.fetchOrCreateActiveRecord(in: context)
        let second = PurchaseDecisionRecord.fetchOrCreateActiveRecord(in: context)

        #expect(first.scenarioID == PurchaseDecisionRecord.activeRecordID)
        #expect(first.persistentModelID == second.persistentModelID)
    }

    @Test("fetchOrCreateActiveRecord preserves edits across subsequent fetches")
    func fetchOrCreatePreservesEdits() throws {
        let context = try makeContext()
        let first = PurchaseDecisionRecord.fetchOrCreateActiveRecord(in: context)
        first.merchantName = "Target"
        first.amount = 80
        first.categoryRawValue = MerchantCategory.groceries.rawValue
        try context.save()

        let second = PurchaseDecisionRecord.fetchOrCreateActiveRecord(in: context)
        #expect(second.merchantName == "Target")
        #expect(second.amount == 80)
        #expect(second.category == .groceries)
    }

    // MARK: - Round-trip

    @Test("Record round-trips through an in-memory SwiftData container")
    func recordRoundTripsThroughContext() throws {
        let context = try makeContext()
        let anchor = PurchaseDecisionRecord.activeRecordID
        let record = PurchaseDecisionRecord(
            scenarioID: anchor,
            merchantName: "Target",
            category: .groceries,
            amount: 125.50,
            currencyCode: .usd,
            countryCode: "San Francisco",
            timingText: "Weekend"
        )
        context.insert(record)
        try context.save()

        var descriptor = FetchDescriptor<PurchaseDecisionRecord>(
            predicate: #Predicate { $0.scenarioID == anchor }
        )
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)

        #expect(fetched.merchantName == "Target")
        #expect(fetched.category == .groceries)
        #expect(fetched.amount == 125.50)
        #expect(fetched.currencyCode == .usd)
        #expect(fetched.countryCode == "San Francisco")
        #expect(fetched.timingText == "Weekend")
    }

    // MARK: - Context projection

    @Test("Record projects into a PurchaseContext the engine can consume")
    func recordProjectsToEngineContext() {
        let record = PurchaseDecisionRecord(
            scenarioID: PurchaseDecisionRecord.activeRecordID,
            merchantName: "Target",
            category: .dining,
            amount: 32,
            currencyCode: .cad,
            countryCode: "Toronto",
            timingText: "Tonight"
        )
        let context = record.context
        #expect(context.merchantName == "Target")
        #expect(context.category == .dining)
        #expect(context.amount == 32)
        #expect(context.currencyCode == .cad)
        #expect(context.countryCode == "Toronto")
        #expect(context.timingText == "Tonight")
        #expect(context.hasUsableAmount)
        #expect(context.isComplete)
    }

    // MARK: - Data governance

    @Test("deleteAllUserData wipes every purchase-decision record")
    func deleteAllUserDataWipesPurchaseRecords() throws {
        let context = try makeContext()
        for _ in 0..<3 {
            let record = PurchaseDecisionRecord(scenarioID: UUID().uuidString)
            context.insert(record)
        }
        try context.save()

        let before = try context.fetch(
            FetchDescriptor<PurchaseDecisionRecord>()
        )
        #expect(before.count == 3)

        let notificationManager = NotificationManager()
        DataGovernancePolicy.deleteAllUserData(
            in: context,
            notificationManager: notificationManager
        )

        let after = try context.fetch(
            FetchDescriptor<PurchaseDecisionRecord>()
        )
        #expect(after.isEmpty)
    }
}
