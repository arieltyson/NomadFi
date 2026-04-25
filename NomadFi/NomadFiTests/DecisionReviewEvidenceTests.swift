// DecisionReviewEvidenceTests.swift
// NomadFi
//
// Pure-logic coverage for the Decision Assistant history-semantics
// hardening. The evidence helper is value-typed and the marker
// utility is `@MainActor`; this suite stays off the SwiftData
// parallel-init crash class by using `SwiftDataTestContainerFactory`
// (which already registers `DecisionReviewMarker`).

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
@Suite(.serialized)
struct DecisionReviewEvidenceTests {

    // MARK: - reviewedDecisionIDs(...)

    @Test("Fresh user (no scenario inputs, no purchase amount, no marker) → empty reviewed set — empty-state path is reachable")
    func freshUserHasNoReviewedDecisions() {
        let reviewed = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: false,
            purchaseHasUsableContext: false,
            creditTimingMarkerStamped: false
        )
        #expect(reviewed.isEmpty)
    }

    @Test("Scenario interaction alone surfaces only Amazon under Previous decisions")
    func scenarioInteractionOnly() {
        let reviewed = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: true,
            purchaseHasUsableContext: false,
            creditTimingMarkerStamped: false
        )
        #expect(reviewed == [.amazonArrivalOrder])
    }

    @Test("Purchase usable context alone surfaces only Purchase Card Check")
    func purchaseContextOnly() {
        let reviewed = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: false,
            purchaseHasUsableContext: true,
            creditTimingMarkerStamped: false
        )
        #expect(reviewed == [.purchaseCardCheck])
    }

    @Test("Credit Timing marker alone surfaces only Credit Timing — having a card on file does NOT count")
    func creditTimingMarkerOnly() {
        let reviewed = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: false,
            purchaseHasUsableContext: false,
            creditTimingMarkerStamped: true
        )
        #expect(reviewed == [.creditTimingCheck])
    }

    @Test("All three signals true → all three IDs in the reviewed set")
    func allThreeSignalsReviewed() {
        let reviewed = DecisionReviewEvidence.reviewedDecisionIDs(
            scenarioInteracted: true,
            purchaseHasUsableContext: true,
            creditTimingMarkerStamped: true
        )
        #expect(reviewed == [
            .amazonArrivalOrder,
            .purchaseCardCheck,
            .creditTimingCheck,
        ])
    }

    // MARK: - markerStamped(for:in:)

    @Test("markerStamped returns false for an empty marker list")
    func markerStampedEmptyList() {
        #expect(
            DecisionReviewEvidence.markerStamped(
                for: .creditTimingCheck,
                in: []
            ) == false
        )
    }

    @Test("markerStamped returns false for a row whose lastReviewedAt is nil")
    func markerStampedNilTimestamp() {
        let unstamped = DecisionReviewMarker(
            decisionIDRawValue: DecisionID.creditTimingCheck.rawValue,
            lastReviewedAt: nil
        )
        #expect(
            DecisionReviewEvidence.markerStamped(
                for: .creditTimingCheck,
                in: [unstamped]
            ) == false
        )
    }

    @Test("markerStamped returns true for a row whose lastReviewedAt is non-nil")
    func markerStampedNonNilTimestamp() {
        let stamped = DecisionReviewMarker(
            decisionIDRawValue: DecisionID.creditTimingCheck.rawValue,
            lastReviewedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        #expect(
            DecisionReviewEvidence.markerStamped(
                for: .creditTimingCheck,
                in: [stamped]
            ) == true
        )
    }

    @Test("markerStamped is per-decisionID — a marker for one decision does not leak into another")
    func markerStampedIsScopedPerDecision() {
        let creditMarker = DecisionReviewMarker(
            decisionIDRawValue: DecisionID.creditTimingCheck.rawValue,
            lastReviewedAt: .now
        )
        #expect(
            DecisionReviewEvidence.markerStamped(
                for: .amazonArrivalOrder,
                in: [creditMarker]
            ) == false
        )
        #expect(
            DecisionReviewEvidence.markerStamped(
                for: .purchaseCardCheck,
                in: [creditMarker]
            ) == false
        )
    }

    // MARK: - DecisionReviewMarker persistence

    @Test("fetchOrCreate(for:in:) inserts exactly one row on first call")
    func fetchOrCreateInsertsOnce() throws {
        let context = try SwiftDataTestContainerFactory.makeFullSchemaContext()

        let first = DecisionReviewMarker.fetchOrCreate(
            for: .creditTimingCheck,
            in: context
        )
        #expect(first.decisionIDRawValue == DecisionID.creditTimingCheck.rawValue)
        #expect(first.lastReviewedAt == nil)

        let second = DecisionReviewMarker.fetchOrCreate(
            for: .creditTimingCheck,
            in: context
        )
        #expect(second.persistentModelID == first.persistentModelID)

        let all = try context.fetch(FetchDescriptor<DecisionReviewMarker>())
        #expect(all.count == 1)
    }

    @Test("stamp(_:in:now:) persists lastReviewedAt and survives a re-fetch")
    func stampPersistsLastReviewedAt() throws {
        let context = try SwiftDataTestContainerFactory.makeFullSchemaContext()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        DecisionReviewMarker.stamp(
            .creditTimingCheck,
            in: context,
            now: now
        )

        let refetched = try context.fetch(
            FetchDescriptor<DecisionReviewMarker>()
        )
        #expect(refetched.count == 1)
        #expect(refetched.first?.lastReviewedAt == now)

        // Stamping again replaces the timestamp, doesn't add a row.
        let later = now.addingTimeInterval(3600)
        DecisionReviewMarker.stamp(
            .creditTimingCheck,
            in: context,
            now: later
        )

        let final = try context.fetch(
            FetchDescriptor<DecisionReviewMarker>()
        )
        #expect(final.count == 1)
        #expect(final.first?.lastReviewedAt == later)
    }

    @Test("openCreditTimingBrief(modelContext:) stamps the Credit Timing marker — purely user-invoked review evidence")
    func openCreditTimingStampsTheMarker() throws {
        let context = try SwiftDataTestContainerFactory.makeFullSchemaContext()
        let viewModel = DecisionAssistantViewModel()
        viewModel.bootstrap(modelContext: context)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        viewModel.openCreditTimingBrief(modelContext: context, now: now)

        let markers = try context.fetch(
            FetchDescriptor<DecisionReviewMarker>()
        )
        let creditMarker = try #require(
            markers.first { $0.decisionIDRawValue == DecisionID.creditTimingCheck.rawValue }
        )
        #expect(creditMarker.lastReviewedAt == now)
        #expect(viewModel.isCreditTimingBriefPresented)

        // The reviewed-set rule honours the freshly-stamped marker.
        let reviewed = viewModel.reviewedDecisions(reviewMarkers: markers)
        #expect(reviewed.map(\.id) == [.creditTimingCheck])
    }
}
