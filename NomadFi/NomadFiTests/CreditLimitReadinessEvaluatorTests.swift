// CreditLimitReadinessEvaluatorTests.swift
// NomadFi
//
// Pure coverage for the credit-limit-increase readiness checklist.
// The evaluator is a value-in / value-out function, so there's no
// SwiftData container and tests can run in parallel.
//
// The product contract pinned here:
//   • NomadFi never says a user is approved, nor predicts a credit
//     score outcome, nor recommends carrying a balance.
//   • Issuer-only facts stay as `.issuerOnly` forever — the
//     evaluator can never flip them to `.met`.
//   • A card rolls up to `.readyToReview` only when every
//     NomadFi-visible check passes.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct CreditLimitReadinessEvaluatorTests {

    // MARK: - Helpers

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

    nonisolated private static let now = date(year: 2026, month: 4, day: 22)

    private static func assessment(
        id: String = "card",
        name: String = "Sample Rewards",
        institution: String = "Example Bank",
        ruling: CreditTimingCardRuling = .readyNoUrgentAction,
        utilization: Double? = 0.15,
        band: CreditTimingUtilizationBand? = .planning,
        balance: Double? = 1_500,
        limit: Double? = 10_000,
        snapshotAt: Date? = now,
        stale: Bool = false,
        schedule: CreditCardScheduleState = .confirmed
    ) -> CreditTimingCardAssessment {
        CreditTimingCardAssessment(
            id: id,
            accountName: name,
            institutionName: institution,
            currencyCode: "USD",
            ruling: ruling,
            utilization: utilization,
            utilizationBand: band,
            currentBalance: balance,
            creditLimit: limit,
            statementClosingDate: date(year: 2026, month: 4, day: 28),
            paymentDueDate: date(year: 2026, month: 5, day: 25),
            snapshotUpdatedAt: snapshotAt,
            snapshotIsStale: stale,
            scheduleState: schedule,
            paydownTargetTo30Percent: nil,
            paydownTargetTo10Percent: nil,
            outstandingChecks: []
        )
    }

    private static func nomadVisibleItems(
        _ summary: CreditLimitReadinessCardSummary
    ) -> [CreditLimitReadinessItem] {
        summary.items.filter { $0.status != .issuerOnly }
    }

    // MARK: - Ready path

    @Test("A card with every NomadFi-visible check passing rolls up to readyToReview")
    func readyToReviewWhenVisibleChecksMet() throws {
        let card = Self.assessment()
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [card],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        #expect(summary.summary == .readyToReview)
        let visible = Self.nomadVisibleItems(summary)
        #expect(visible.allSatisfy { $0.status == .met })
        #expect(checklist.readyToReviewCount == 1)
    }

    // MARK: - Not-ready paths

    @Test("High utilization (elevated band) blocks the card from being readyToReview")
    func highUtilizationBlocksReady() throws {
        let highUtil = Self.assessment(
            ruling: .payDownBeforeClose,
            utilization: 0.55,
            band: .elevated,
            balance: 5_500
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [highUtil],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        #expect(summary.summary == .needsMoreEvidence)
        let utilizationItem = try #require(
            summary.items.first(where: { $0.id == "utilization_band" })
        )
        #expect(utilizationItem.status == .notMet)
    }

    @Test("Near-limit card is flagged notMet on the 'no near-limit signal' row")
    func nearLimitBlocksReady() throws {
        let nearLimit = Self.assessment(
            ruling: .nearLimitAvoidMoreSpend,
            utilization: 0.95,
            band: .nearLimit,
            balance: 9_500
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [nearLimit],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        #expect(summary.summary == .needsMoreEvidence)
        let nearLimitItem = try #require(
            summary.items.first(where: { $0.id == "no_near_limit" })
        )
        #expect(nearLimitItem.status == .notMet)
    }

    @Test("Stale snapshot flips the freshness check to notMet and blocks the ready rollup")
    func staleSnapshotBlocksReady() throws {
        let stale = Self.assessment(stale: true)
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [stale],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        #expect(summary.summary == .needsMoreEvidence)
        let freshness = try #require(
            summary.items.first(where: { $0.id == "snapshot_freshness" })
        )
        #expect(freshness.status == .notMet)
    }

    @Test("Unconfirmed statement calendar blocks ready rollup")
    func unconfirmedScheduleBlocksReady() throws {
        let partial = Self.assessment(schedule: .partial)
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [partial],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        #expect(summary.summary == .needsMoreEvidence)
        let calendar = try #require(
            summary.items.first(where: { $0.id == "statement_calendar" })
        )
        #expect(calendar.status == .notMet)
    }

    @Test("Missing credit limit surfaces as missing, not as zero or 'met'")
    func missingLimitSurfacesAsMissing() throws {
        let noLimit = Self.assessment(
            ruling: .needsSetup,
            utilization: nil,
            band: nil,
            limit: nil
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [noLimit],
            now: Self.now
        )
        let summary = try #require(checklist.cardSummaries.first)
        let limitItem = try #require(
            summary.items.first(where: { $0.id == "credit_limit" })
        )
        #expect(limitItem.status == .missing)
    }

    // MARK: - Issuer-only invariant

    @Test("Issuer-only facts are always surfaced as .issuerOnly, never flipped by the evaluator")
    func issuerOnlyFactsStayUnknown() {
        // Best-case card; issuer-only items should still be present
        // and all tagged `.issuerOnly`.
        let best = Self.assessment()
        // Worst-case card; same invariant.
        let worst = Self.assessment(
            id: "worst",
            name: "Worst",
            ruling: .nearLimitAvoidMoreSpend,
            utilization: 0.98,
            band: .nearLimit,
            balance: 9_800,
            stale: true,
            schedule: .partial
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [best, worst],
            now: Self.now
        )
        let issuerIDs: Set<String> = [
            "income",
            "payment_history",
            "account_age",
            "hard_inquiry_policy",
            "issuer_eligibility",
        ]
        for summary in checklist.cardSummaries {
            let issuerItems = summary.items.filter { issuerIDs.contains($0.id) }
            #expect(issuerItems.count == issuerIDs.count)
            for item in issuerItems {
                #expect(item.status == .issuerOnly)
            }
        }
    }

    // MARK: - Sorting

    @Test("needsMoreEvidence cards sort before readyToReview cards")
    func sortingPutsActionableFirst() throws {
        let ready = Self.assessment(id: "ready", name: "Ready")
        let needs = Self.assessment(
            id: "needs",
            name: "Needs",
            stale: true
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [ready, needs],
            now: Self.now
        )
        #expect(checklist.cardSummaries.first?.id.contains("needs") == true)
    }

    // MARK: - Copy / vocabulary guard

    @Test("Readiness copy never uses the banned Phase 6 vocabulary")
    func copyGuardOnReadinessVocab() {
        let bannedPhrases: [String] = [
            "guarantee",
            "score will increase",
            "approved",
            "will get a limit increase",
            "carry a balance",
        ]

        var inspected: [String] = []

        // Global caveats.
        inspected.append(contentsOf: CreditLimitReadinessEvaluator.defaultGlobalCaveats)

        // Status labels.
        for status in CreditLimitReadinessStatus.allCases {
            inspected.append(status.displayLabel)
            inspected.append(status.accessibilityLabel)
        }
        for summary in CreditLimitReadinessSummary.allCases {
            inspected.append(summary.displayLabel)
            inspected.append(summary.accessibilityLabel)
        }

        // Every item title + detail for best + worst inputs.
        let best = Self.assessment()
        let worst = Self.assessment(
            id: "worst",
            ruling: .nearLimitAvoidMoreSpend,
            utilization: 0.98,
            band: .nearLimit,
            balance: 9_800,
            limit: 10_000,
            stale: true,
            schedule: .partial
        )
        let checklist = CreditLimitReadinessEvaluator.evaluate(
            assessments: [best, worst],
            now: Self.now
        )
        for summary in checklist.cardSummaries {
            for item in summary.items {
                inspected.append(item.title)
                inspected.append(item.detail)
            }
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in readiness copy: \(copy)"
                )
            }
        }
    }
}
