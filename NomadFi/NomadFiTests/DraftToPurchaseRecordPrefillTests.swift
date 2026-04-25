// DraftToPurchaseRecordPrefillTests.swift
// NomadFi
//
// Phase 1 follow-through coverage. The prefill is pure over its
// inputs but mutates a SwiftData `@Model` reference, so the suite
// is `@MainActor` and constructs records without inserting them
// into a `ModelContainer` (matches the existing prefill /
// view-model test pattern).
//
// Pinned product contract:
//
//   • Prefill is strictly user-invoked. The helper itself does
//     nothing automatic; these tests just exercise the mutation.
//   • The draft's status is never flipped to "analyzed".
//   • Empty / nil draft fields do not overwrite existing record
//     fields. The user's last typed brief input wins.
//   • Travel-kind drafts pick the `.travel` merchant category.
//     Generic purchase-kind drafts default to `.general`.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct DraftToPurchaseRecordPrefillTests {

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

    private static let now = date(year: 2026, month: 4, day: 24)

    // MARK: - Helpers

    private func freshRecord() -> PurchaseDecisionRecord {
        PurchaseDecisionRecord(
            scenarioID: PurchaseDecisionRecord.activeRecordID
        )
    }

    private func purchaseDraft(
        amount: Double? = 80,
        merchant: String = "Target",
        location: String = "San Francisco",
        timing: String = "this weekend",
        currency: CurrencyCode = .usd
    ) -> DecisionDraftRecord {
        DecisionDraftRecord(
            title: "Purchase draft",
            scenarioText: "test",
            kind: .purchase,
            merchantName: merchant,
            locationText: location,
            amount: amount,
            currencyCode: currency,
            timingText: timing
        )
    }

    private func travelDraft(
        amount: Double? = 250,
        location: String = "Lisbon"
    ) -> DecisionDraftRecord {
        DecisionDraftRecord(
            title: "Travel draft",
            scenarioText: "test",
            kind: .travel,
            merchantName: "Airline",
            locationText: location,
            amount: amount,
            currencyCode: .eur,
            timingText: ""
        )
    }

    // MARK: - Field copy

    @Test("Purchase prefill copies merchant, location, amount, currency, and timing onto the record")
    func purchasePrefillCopiesStructuredFields() {
        let record = freshRecord()
        let draft = purchaseDraft()

        DraftToPurchaseRecordPrefill.apply(
            draft: draft,
            into: record,
            now: Self.now
        )

        #expect(record.merchantName == "Target")
        #expect(record.countryCode == "San Francisco")
        #expect(record.timingText == "this weekend")
        #expect(record.amount == 80)
        #expect(record.currencyCode == .usd)
        #expect(record.updatedAt == Self.now)
    }

    @Test("Empty / nil draft fields never overwrite a record's previously typed brief input")
    func emptyDraftFieldsDoNotOverwriteRecord() {
        let record = freshRecord()
        record.merchantName = "Existing merchant"
        record.countryCode = "Existing location"
        record.timingText = "Existing timing"
        record.amount = 999

        let draft = purchaseDraft(
            amount: nil,
            merchant: "",
            location: "   ",
            timing: ""
        )

        DraftToPurchaseRecordPrefill.apply(
            draft: draft,
            into: record,
            now: Self.now
        )

        #expect(record.merchantName == "Existing merchant")
        #expect(record.countryCode == "Existing location")
        #expect(record.timingText == "Existing timing")
        #expect(record.amount == 999)
    }

    @Test("Zero / negative draft amounts never overwrite a record's existing positive amount")
    func zeroDraftAmountDoesNotOverwriteRecord() {
        let record = freshRecord()
        record.amount = 120
        let draft = purchaseDraft(amount: 0)

        DraftToPurchaseRecordPrefill.apply(draft: draft, into: record, now: Self.now)

        #expect(record.amount == 120)
    }

    // MARK: - Category mapping

    @Test("Travel-kind drafts map to MerchantCategory.travel")
    func travelKindMapsToTravelCategory() {
        let record = freshRecord()
        DraftToPurchaseRecordPrefill.apply(
            draft: travelDraft(),
            into: record,
            now: Self.now
        )
        #expect(record.category == .travel)
    }

    @Test("Generic purchase-kind drafts map to MerchantCategory.general")
    func purchaseKindMapsToGeneralCategory() {
        let record = freshRecord()
        DraftToPurchaseRecordPrefill.apply(
            draft: purchaseDraft(),
            into: record,
            now: Self.now
        )
        #expect(record.category == .general)
    }

    @Test("Defensive: non-purchase / non-travel kinds default to .general (never crashes the mapping)")
    func defensiveCategoryMapping() {
        let cases: [(DecisionDraftKind, MerchantCategory)] = [
            (.purchase, .general),
            (.travel, .travel),
            (.creditTiming, .general),
            (.taxEducation, .general),
            (.investingEducation, .general),
            (.other, .general),
        ]
        for (kind, expected) in cases {
            #expect(DraftToPurchaseRecordPrefill.mapCategory(for: kind) == expected)
        }
    }

    // MARK: - No-status-promotion

    @Test("Prefill never flips the draft's persisted status — drafts stay needsEngine")
    func draftStatusIsNeverPromoted() {
        let record = freshRecord()
        let draft = purchaseDraft()
        let originalStatus = draft.status

        DraftToPurchaseRecordPrefill.apply(draft: draft, into: record, now: Self.now)

        #expect(draft.status == originalStatus)
        #expect(draft.status == .needsEngine)
    }

    @Test("Prefill never mutates the draft itself — the draft's amount and merchant remain captured exactly as before")
    func draftItselfIsNotMutated() {
        let record = freshRecord()
        let draft = purchaseDraft(amount: 80, merchant: "Target")
        let originalUpdatedAt = draft.updatedAt

        DraftToPurchaseRecordPrefill.apply(draft: draft, into: record, now: Self.now)

        #expect(draft.amount == 80)
        #expect(draft.merchantName == "Target")
        #expect(draft.updatedAt == originalUpdatedAt)
    }

    // MARK: - Currency

    @Test("Currency raw value is always copied — even when the record had a different default")
    func currencyIsAlwaysCopied() {
        let record = freshRecord()
        record.currencyCodeRawValue = CurrencyCode.cad.rawValue

        let draft = purchaseDraft(currency: .eur)
        DraftToPurchaseRecordPrefill.apply(draft: draft, into: record, now: Self.now)

        #expect(record.currencyCode == .eur)
    }
}
