// CreditTimingSpendingContextDecisionTests.swift
// NomadFi
//
// Pins the integration contract between the spending-trend summary
// and the Credit Timing engine:
//
//   • When no trend is passed, `CreditTimingDecision.spendingContext`
//     is nil and every other field is byte-for-byte identical to the
//     pre-Phase 6B output.
//   • When a trend is passed, the decision carries a context and the
//     paydown targets stay untouched.
//   • The allocation plan, readiness checklist, and hard rules are
//     unaffected by the trend summary.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct CreditTimingSpendingContextDecisionTests {

    // MARK: - Fixture helpers

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

    private func makeCreditCard(
        name: String = "Sample Rewards",
        institution: String = "Example Bank",
        creditLimit: Double? = 10_000,
        currentBalance: Double? = 4_500
    ) -> Account {
        Account(
            name: name,
            institutionName: institution,
            accountType: .creditCard,
            currencyCode: .usd,
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: Self.date(year: 2026, month: 4, day: 21),
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            financialSnapshotUpdatedAt: Self.now,
            financialSnapshotSource: .userSnapshot
        )
    }

    private static func trendSummary() -> SpendingTrendSummary {
        SpendingTrendSummary(
            months: [
                SpendingTrendMonth(year: 2026, month: 2),
                SpendingTrendMonth(year: 2026, month: 3),
                SpendingTrendMonth(year: 2026, month: 4),
            ],
            categoryRows: [
                SpendingTrendCategoryRow(
                    category: .food,
                    totalsByMonth: [250, 300, 400],
                    totalForWindow: 950
                ),
                SpendingTrendCategoryRow(
                    category: .transport,
                    totalsByMonth: [60, 80, 100],
                    totalForWindow: 240
                ),
            ],
            totalsByMonth: [320, 410, 500],
            currencyCode: .usd,
            contributingTransactionCount: 24,
            skippedOtherCurrencyCount: 2
        )
    }

    // MARK: - Preservation when no trend is supplied

    @Test("Decision with no spending trend is unchanged — spendingContext is nil and allocation/readiness stay stable")
    func noTrendPreservesLegacyOutput() {
        let card = makeCreditCard()

        let baseline = CreditTimingDecisionEngine.decide(
            accounts: [card],
            now: Self.now
        )
        let withExplicitNil = CreditTimingDecisionEngine.decide(
            accounts: [card],
            now: Self.now,
            spendingTrend: nil
        )

        #expect(baseline.spendingContext == nil)
        #expect(withExplicitNil.spendingContext == nil)
        #expect(baseline == withExplicitNil)
    }

    // MARK: - Context is attached when trend is supplied

    @Test("Decision with a trend carries a spending context and preserves allocation totals")
    func trendAttachesContextWithoutChangingTargets() throws {
        let card = makeCreditCard()

        let baseline = CreditTimingDecisionEngine.decide(
            accounts: [card],
            now: Self.now
        )
        let enriched = CreditTimingDecisionEngine.decide(
            accounts: [card],
            now: Self.now,
            spendingTrend: Self.trendSummary()
        )

        let context = try #require(enriched.spendingContext)
        #expect(context.currencyCode == .usd)
        #expect(context.latestMonth == SpendingTrendMonth(year: 2026, month: 4))
        #expect(context.latestMonthTotal == 500)
        #expect(context.priorComparisonLabel == "trailing 2-month average")
        #expect(context.skippedOtherCurrencyCount == 2)

        // Critical invariant: adding a trend must never change the
        // allocation plan's paydown numbers.
        #expect(enriched.paymentAllocation.groups == baseline.paymentAllocation.groups)
        #expect(enriched.paymentAllocation.blockers == baseline.paymentAllocation.blockers)

        // Per-card paydown targets are identical assessment-for-assessment.
        for (lhs, rhs) in zip(enriched.cardAssessments, baseline.cardAssessments) {
            #expect(lhs.paydownTargetTo30Percent == rhs.paydownTargetTo30Percent)
            #expect(lhs.paydownTargetTo10Percent == rhs.paydownTargetTo10Percent)
        }

        // Readiness checklist and hard rules are unaffected.
        #expect(enriched.limitReadiness == baseline.limitReadiness)
        #expect(enriched.hardRules == baseline.hardRules)
        #expect(enriched.ruling == baseline.ruling)
        #expect(enriched.missingDataChecklist == baseline.missingDataChecklist)
    }

    // MARK: - No-credit-card path still attaches context

    @Test("With no credit cards on file the decision still carries the spending context as a nil-safe signal")
    func noCardsStillExposesContext() throws {
        let checking = Account(
            name: "Checking",
            institutionName: "Example Bank",
            accountType: .checking,
            currencyCode: .usd,
            creditLimit: nil,
            currentBalance: 3_000
        )

        let decision = CreditTimingDecisionEngine.decide(
            accounts: [checking],
            now: Self.now,
            spendingTrend: Self.trendSummary()
        )

        #expect(decision.ruling == .noCreditCardsOnFile)
        let context = try #require(decision.spendingContext)
        #expect(context.direction == .rising)
    }
}
