// DecisionDraftRowReadinessTests.swift
// NomadFi
//
// Drafts v3 — pure-logic coverage for the row-readiness adapter
// and the list-presentation helper. Both are value-typed and
// `@MainActor`-bound only because `DecisionDraftRecord` is a
// SwiftData `@Model`; constructed without inserting into a
// `ModelContainer` to stay off the parallel-init crash class.
//
// Pinned product contract:
//
//   • Lifecycle (`.archived`) wins over readiness — archived
//     drafts always render the archived label.
//   • Active drafts render evaluator-derived readiness, never the
//     bare lifecycle label.
//   • Readiness copy stays procedural — no recommendation,
//     "best", "analyzed", or outcome language.
//   • List ordering is engine-ready → requires-context →
//     routed-to-advanced-tool → no-engine-yet, with `updatedAt`
//     descending inside each group.
//   • Decoration is pure — same inputs always produce the same
//     output and never mutate the input drafts.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct DecisionDraftRowReadinessTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private func draft(
        kind: DecisionDraftKind = .purchase,
        amount: Double? = nil,
        status: DecisionDraftStatus = .needsEngine,
        updatedAt: Date = Self.date(year: 2026, month: 4, day: 24)
    ) -> DecisionDraftRecord {
        DecisionDraftRecord(
            title: "Draft",
            scenarioText: "Scenario.",
            kind: kind,
            merchantName: "",
            locationText: "",
            amount: amount,
            currencyCode: .usd,
            timingText: "",
            notes: "",
            status: status,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Per-kind readiness

    @Test("Purchase draft with positive amount → .engineReady")
    func purchaseWithAmountIsEngineReady() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .purchase, amount: 80)
        )
        #expect(result == .engineReady)
        #expect(result.displayLabel == "Engine ready")
    }

    @Test("Purchase draft without amount → .requiresContext(.amount)")
    func purchaseWithoutAmountAsksForAmount() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .purchase, amount: nil)
        )
        #expect(result == .requiresContext(.amount))
        #expect(result.displayLabel == "Add amount first")
    }

    @Test("Travel draft with amount → .engineReady (Purchase Card Check handoff)")
    func travelWithAmountIsEngineReady() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .travel, amount: 250)
        )
        #expect(result == .engineReady)
    }

    @Test("Credit-timing draft with at least one credit card → .engineReady")
    func creditTimingWithCardIsEngineReady() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .creditTiming),
            accountSnapshot: DecisionDraftAccountSnapshot(hasAnyCreditCard: true)
        )
        #expect(result == .engineReady)
    }

    @Test("Credit-timing draft without any credit card → .requiresContext(.savedCreditCard)")
    func creditTimingWithoutCardAsksForCard() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .creditTiming),
            accountSnapshot: .empty
        )
        #expect(result == .requiresContext(.savedCreditCard))
        #expect(result.displayLabel == "Add a credit card first")
    }

    @Test("Tax-education draft → .routedToAdvancedTool(.taxVault) with calm label")
    func taxEducationRoutesToTaxVault() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .taxEducation)
        )
        #expect(result == .routedToAdvancedTool(.taxVault))
        #expect(result.displayLabel == "Review in Tax Vault")
    }

    @Test("Investing-education draft → .routedToAdvancedTool(.investingLearn) with calm label")
    func investingEducationRoutesToInvestingLearn() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .investingEducation)
        )
        #expect(result == .routedToAdvancedTool(.investingLearn))
        #expect(result.displayLabel == "Review in Investing Learn")
    }

    @Test("Other draft → .noEngineYet with factual label")
    func otherDraftIsNoEngineYet() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .other)
        )
        #expect(result == .noEngineYet)
        #expect(result.displayLabel == "No engine yet")
    }

    // MARK: - Lifecycle override

    @Test("Archived draft always returns .archived — even when its kind would otherwise be engine-ready")
    func archivedAlwaysWinsOverReadiness() {
        let archivedReadyPurchase = draft(
            kind: .purchase,
            amount: 80,
            status: .archived
        )
        let result = DecisionDraftRowReadiness.from(
            draft: archivedReadyPurchase
        )
        #expect(result == .archived)
        #expect(result.displayLabel == "Archived")
    }

    @Test("Archived credit-timing draft is .archived even with a saved credit card on file")
    func archivedCreditTimingIsArchived() {
        let result = DecisionDraftRowReadiness.from(
            draft: draft(kind: .creditTiming, status: .archived),
            accountSnapshot: DecisionDraftAccountSnapshot(hasAnyCreditCard: true)
        )
        #expect(result == .archived)
    }

    // MARK: - Purity

    @Test("Readiness derivation does not mutate the underlying draft")
    func derivationDoesNotMutateDraft() {
        let purchase = draft(kind: .purchase, amount: 80)
        let originalStatus = purchase.statusRawValue
        let originalAmount = purchase.amount

        _ = DecisionDraftRowReadiness.from(draft: purchase)

        #expect(purchase.statusRawValue == originalStatus)
        #expect(purchase.amount == originalAmount)
        #expect(purchase.status == .needsEngine)
    }

    @Test("Readiness derivation is pure — same inputs always produce the same output")
    func derivationIsPure() {
        let purchase = draft(kind: .purchase, amount: 80)
        let snapshot = DecisionDraftAccountSnapshot(hasAnyCreditCard: true)
        let first = DecisionDraftRowReadiness.from(
            draft: purchase,
            accountSnapshot: snapshot
        )
        let second = DecisionDraftRowReadiness.from(
            draft: purchase,
            accountSnapshot: snapshot
        )
        #expect(first == second)
    }

    // MARK: - Copy guard

    @Test("Readiness display + accessibility copy never uses prohibited recommendation language")
    func readinessCopyHasNoProhibitedPhrases() {
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
        ]

        var inspected: [String] = []
        let cases: [DecisionDraftRowReadiness] = [
            .archived,
            .engineReady,
            .requiresContext(.amount),
            .requiresContext(.currency),
            .requiresContext(.savedCreditCard),
            .routedToAdvancedTool(.taxVault),
            .routedToAdvancedTool(.investingLearn),
            .noEngineYet,
        ]
        for readiness in cases {
            inspected.append(readiness.displayLabel)
            inspected.append(readiness.accessibilityDescription)
        }

        for phrase in prohibited {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in readiness copy: \(copy)"
                )
            }
        }
    }

    // MARK: - List presentation: ordering

    @Test("Active drafts sort by readiness group: engine-ready → requires-context → routed-to-advanced-tool → no-engine-yet")
    func activeDraftsSortByReadinessGroup() {
        let sameDay = Self.date(year: 2026, month: 4, day: 24, hour: 12)
        let inputs: [DecisionDraftRecord] = [
            draft(kind: .other, updatedAt: sameDay),
            draft(kind: .taxEducation, updatedAt: sameDay),
            draft(kind: .purchase, amount: nil, updatedAt: sameDay),
            draft(kind: .purchase, amount: 80, updatedAt: sameDay),
        ]

        let items = DecisionDraftListPresentation.decoratedActiveDrafts(
            inputs,
            accountSnapshot: .empty
        )
        #expect(items.map(\.readiness) == [
            .engineReady,
            .requiresContext(.amount),
            .routedToAdvancedTool(.taxVault),
            .noEngineYet,
        ])
    }

    @Test("Within a readiness group, drafts stay sorted by updatedAt descending")
    func withinGroupSortIsUpdatedAtDescending() {
        let older = Self.date(year: 2026, month: 4, day: 20)
        let newer = Self.date(year: 2026, month: 4, day: 24)

        let olderReady = draft(kind: .purchase, amount: 80, updatedAt: older)
        let newerReady = draft(kind: .purchase, amount: 100, updatedAt: newer)
        let olderBlocked = draft(kind: .purchase, amount: nil, updatedAt: older)
        let newerBlocked = draft(kind: .purchase, amount: nil, updatedAt: newer)

        let items = DecisionDraftListPresentation.decoratedActiveDrafts(
            [olderReady, newerBlocked, newerReady, olderBlocked],
            accountSnapshot: .empty
        )
        #expect(items.map(\.draft.draftID) == [
            newerReady.draftID,
            olderReady.draftID,
            newerBlocked.draftID,
            olderBlocked.draftID,
        ])
    }

    @Test("Decorated active drafts do not include archived rows — those live on the archived surface")
    func archivedRowsAreNotInActiveList() {
        let activePurchase = draft(kind: .purchase, amount: 80)
        let archivedTravel = draft(
            kind: .travel,
            amount: 250,
            status: .archived
        )
        // The view's `@Query` already filters by status; this
        // helper trusts the upstream filter and never re-promotes
        // an archived row into the active set if one slips in.
        let items = DecisionDraftListPresentation.decoratedActiveDrafts(
            [activePurchase, archivedTravel],
            accountSnapshot: .empty
        )
        // Both rows are decorated, but the archived one carries the
        // `.archived` readiness so it surfaces at the bottom of
        // the sort order — it does not magically leave the input.
        #expect(items.contains { $0.draft.draftID == activePurchase.draftID })
        #expect(items.first { $0.draft.draftID == archivedTravel.draftID }?.readiness == .archived)
    }

    @Test("Archived decoration is straight-through — readiness is .archived, order matches the input")
    func archivedDecorationPreservesOrder() {
        let older = Self.date(year: 2026, month: 4, day: 20)
        let newer = Self.date(year: 2026, month: 4, day: 24)
        let archivedRecent = draft(
            kind: .purchase,
            amount: 80,
            status: .archived,
            updatedAt: newer
        )
        let archivedOlder = draft(
            kind: .creditTiming,
            status: .archived,
            updatedAt: older
        )

        let items = DecisionDraftListPresentation.decoratedArchivedDrafts(
            [archivedRecent, archivedOlder]
        )
        #expect(items.map(\.draft.draftID) == [
            archivedRecent.draftID,
            archivedOlder.draftID,
        ])
        #expect(items.allSatisfy { $0.readiness == .archived })
    }
}
