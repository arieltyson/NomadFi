// CreditPaymentAllocationPlannerTests.swift
// NomadFi
//
// Pure-value coverage for the Phase 6A allocation planner. The
// planner consumes `CreditTimingCardAssessment` values only, so no
// SwiftData container is needed and tests can run in parallel.
//
// Each test pins one rule from the planner's rule list — the
// combination is the contract the brief view and voice surface
// rely on.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct CreditPaymentAllocationPlannerTests {

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

    /// A complete, planner-eligible assessment by default. Each
    /// argument lets a test bend exactly one field.
    private static func assessment(
        id: String = "card",
        name: String = "Sample Rewards",
        institution: String = "Example Bank",
        currency: String = "USD",
        ruling: CreditTimingCardRuling = .payDownBeforeClose,
        utilization: Double? = 0.45,
        band: CreditTimingUtilizationBand? = .elevated,
        balance: Double? = 4_500,
        limit: Double? = 10_000,
        close: Date? = date(year: 2026, month: 4, day: 28),
        snapshotAt: Date? = now,
        stale: Bool = false,
        schedule: CreditCardScheduleState = .confirmed,
        paydownTo30: Double? = 1_500,
        paydownTo10: Double? = 3_500
    ) -> CreditTimingCardAssessment {
        CreditTimingCardAssessment(
            id: id,
            accountName: name,
            institutionName: institution,
            currencyCode: currency,
            ruling: ruling,
            utilization: utilization,
            utilizationBand: band,
            currentBalance: balance,
            creditLimit: limit,
            statementClosingDate: close,
            paymentDueDate: close.map { date -> Date in
                Calendar(identifier: .gregorian).date(byAdding: .day, value: 25, to: date) ?? date
            },
            snapshotUpdatedAt: snapshotAt,
            snapshotIsStale: stale,
            scheduleState: schedule,
            paydownTargetTo30Percent: paydownTo30,
            paydownTargetTo10Percent: paydownTo10,
            outstandingChecks: []
        )
    }

    // MARK: - Eligibility

    @Test("Cards with no credit limit or no balance snapshot are excluded as blockers, not silently dropped")
    func missingLimitOrBalanceBlocks() {
        let noLimit = Self.assessment(
            id: "a",
            name: "No Limit Card",
            ruling: .needsSetup,
            utilization: nil,
            band: nil,
            limit: nil,
            paydownTo30: nil,
            paydownTo10: nil
        )
        let noBalance = Self.assessment(
            id: "b",
            name: "No Balance Card",
            ruling: .needsSetup,
            utilization: nil,
            band: nil,
            balance: nil,
            paydownTo30: nil,
            paydownTo10: nil
        )

        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [noLimit, noBalance],
            now: Self.now
        )

        #expect(plan.groups.isEmpty)
        #expect(plan.blockers.count == 2)
        let reasons = Set(plan.blockers.map(\.reason))
        #expect(reasons == Set([
            CreditPaymentAllocationBlockerReason.missingCreditLimit,
            CreditPaymentAllocationBlockerReason.missingBalanceSnapshot,
        ]))
    }

    @Test("Stale snapshot blocks strong allocation, even when a ruling was issued before staleness took effect")
    func staleSnapshotBlocks() {
        let stale = Self.assessment(stale: true)
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [stale],
            now: Self.now
        )
        #expect(plan.groups.isEmpty)
        #expect(plan.blockers.first?.reason == .staleSnapshot)
    }

    @Test("Unconfirmed statement calendar blocks strong allocation")
    func unconfirmedScheduleBlocks() {
        let partial = Self.assessment(schedule: .partial)
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [partial],
            now: Self.now
        )
        #expect(plan.groups.isEmpty)
        #expect(plan.blockers.first?.reason == .unconfirmedSchedule)
    }

    @Test("Cards already under the conservative 30% target surface as a belowConservativeTarget blocker")
    func underConservativeTargetSurfacesBlocker() {
        let ready = Self.assessment(
            ruling: .readyNoUrgentAction,
            utilization: 0.15,
            band: .planning,
            paydownTo30: nil,
            paydownTo10: nil
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [ready],
            now: Self.now
        )
        #expect(plan.groups.isEmpty)
        #expect(plan.blockers.first?.reason == .belowConservativeTarget)
    }

    // MARK: - Priority

    @Test("Near-limit card sorts before elevated (pay-down-before-close) card")
    func nearLimitBeforeElevated() throws {
        let nearLimit = Self.assessment(
            id: "near",
            name: "Near Limit Card",
            ruling: .nearLimitAvoidMoreSpend,
            utilization: 0.95,
            band: .nearLimit,
            balance: 9_500,
            paydownTo30: 6_500,
            paydownTo10: 8_500
        )
        let elevated = Self.assessment(
            id: "elev",
            name: "Elevated Card",
            ruling: .payDownBeforeClose,
            utilization: 0.45,
            band: .elevated
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [elevated, nearLimit],
            now: Self.now
        )

        let group = try #require(plan.groups.first)
        #expect(group.lines.count == 2)
        #expect(group.lines[0].id == "near")
        #expect(group.lines[0].priority == 0)
        #expect(group.lines[1].id == "elev")
        #expect(group.lines[1].priority == 1)
    }

    @Test("When severity ties, earlier confirmed statement close sorts before later close")
    func earlierCloseWinsTie() throws {
        let earlier = Self.assessment(
            id: "earlier",
            name: "Earlier",
            ruling: .payDownBeforeClose,
            close: Self.date(year: 2026, month: 4, day: 27)
        )
        let later = Self.assessment(
            id: "later",
            name: "Later",
            ruling: .payDownBeforeClose,
            close: Self.date(year: 2026, month: 5, day: 12)
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [later, earlier],
            now: Self.now
        )
        let group = try #require(plan.groups.first)
        #expect(group.lines[0].id == "earlier")
        #expect(group.lines[1].id == "later")
    }

    @Test("When severity + close-date tie, higher utilization sorts first")
    func higherUtilizationWinsNextTie() throws {
        let close = Self.date(year: 2026, month: 4, day: 27)
        let lowerUtil = Self.assessment(
            id: "lo",
            name: "Lower",
            institution: "AA Bank",
            utilization: 0.35,
            band: .elevated,
            balance: 3_500,
            close: close,
            paydownTo30: 500,
            paydownTo10: 2_500
        )
        let higherUtil = Self.assessment(
            id: "hi",
            name: "Higher",
            institution: "AA Bank",
            utilization: 0.55,
            band: .elevated,
            balance: 5_500,
            close: close,
            paydownTo30: 2_500,
            paydownTo10: 4_500
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [lowerUtil, higherUtil],
            now: Self.now
        )
        let group = try #require(plan.groups.first)
        #expect(group.lines[0].id == "hi")
        #expect(group.lines[1].id == "lo")
    }

    // MARK: - Totals

    @Test("Paydown-to-30 and paydown-to-10 totals sum each line's contribution exactly")
    func totalsAreCorrect() throws {
        let a = Self.assessment(
            id: "a",
            name: "A",
            institution: "Bank A",
            paydownTo30: 1_500,
            paydownTo10: 3_500
        )
        let b = Self.assessment(
            id: "b",
            name: "B",
            institution: "Bank B",
            paydownTo30: 500,
            paydownTo10: 1_500
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [a, b],
            now: Self.now
        )

        let group = try #require(plan.groups.first)
        #expect(group.totalPaydownToConservativeTarget == 2_000)
        #expect(group.totalPaydownToStrongTarget == 5_000)
    }

    // MARK: - Currencies

    @Test("Cards denominated in different currencies are grouped, never merged into one total")
    func multiCurrencyStaysGrouped() throws {
        let usd = Self.assessment(
            id: "usd",
            name: "USD Card",
            currency: "USD"
        )
        let cad = Self.assessment(
            id: "cad",
            name: "CAD Card",
            currency: "CAD"
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [usd, cad],
            now: Self.now
        )

        #expect(plan.groups.count == 2)
        #expect(plan.isMultiCurrency)
        let currencies = plan.groups.map(\.currencyCode)
        #expect(Set(currencies) == Set(["USD", "CAD"]))
    }

    // MARK: - Budget distribution

    @Test("Budget distribution fills conservative targets in priority order and never over-allocates")
    func budgetDistributionIsDeterministic() throws {
        let nearLimit = Self.assessment(
            id: "near",
            name: "Near",
            ruling: .nearLimitAvoidMoreSpend,
            utilization: 0.95,
            band: .nearLimit,
            balance: 9_500,
            paydownTo30: 6_500,
            paydownTo10: 8_500
        )
        let elevated = Self.assessment(
            id: "elev",
            name: "Elevated",
            paydownTo30: 1_500,
            paydownTo10: 3_500
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [nearLimit, elevated],
            now: Self.now,
            budget: CreditPaymentAllocationBudget(amount: 2_000, currencyCode: "USD")
        )
        let group = try #require(plan.groups.first)
        let near = try #require(group.lines.first(where: { $0.id == "near" }))
        let elev = try #require(group.lines.first(where: { $0.id == "elev" }))

        // Budget = 2 000. Near-limit conservative target = 6 500 →
        // entire 2 000 lands there. Elevated gets 0.
        #expect(near.suggestedPayment == 2_000)
        #expect(elev.suggestedPayment == 0)
        #expect(group.suggestedTotalPayment == 2_000)
    }

    @Test("Over-funded budgets push into the strong target and still never exceed the strong per-line amount")
    func overfundedBudgetBleedsIntoStrongTarget() throws {
        let card = Self.assessment(
            id: "one",
            name: "Only Card",
            paydownTo30: 500,
            paydownTo10: 1_500
        )
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [card],
            now: Self.now,
            budget: CreditPaymentAllocationBudget(amount: 2_500, currencyCode: "USD")
        )
        let line = try #require(plan.groups.first?.lines.first)

        // Pass 1 consumes 500 (conservative). Pass 2 can take up to
        // 1 000 more (1 500 strong - 500 already applied). The
        // remaining 1 000 of the 2 500 budget is returned unused.
        #expect(line.suggestedPayment == 1_500)
    }

    @Test("A budget in a currency no card matches leaves every suggestion nil")
    func mismatchedBudgetCurrencyLeavesLinesUntouched() throws {
        let usd = Self.assessment(currency: "USD")
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: [usd],
            now: Self.now,
            budget: CreditPaymentAllocationBudget(amount: 500, currencyCode: "CAD")
        )
        let line = try #require(plan.groups.first?.lines.first)
        #expect(line.suggestedPayment == nil)
        #expect(plan.appliedBudget?.currencyCode == "CAD")
    }

    // MARK: - Copy / vocabulary guard

    @Test("Blocker, reason, and plan-line copy never use the banned Phase 6 vocabulary")
    func copyGuardOnAllocatorVocab() {
        let bannedPhrases: [String] = [
            "guarantee",
            "score will increase",
            "approved",
            "will get a limit increase",
            "carry a balance",
        ]

        var inspected: [String] = []

        // Blocker display labels + accessibility labels.
        for reason in CreditPaymentAllocationBlockerReason.allCases {
            inspected.append(reason.displayLabel)
            inspected.append(reason.accessibilityLabel)
        }

        // Target display labels + accessibility labels.
        for target in CreditPaymentAllocationTarget.allCases {
            inspected.append(target.displayLabel)
            inspected.append(target.accessibilityLabel)
        }

        // Planner-generated plan-line reasons, exercised across
        // every ruling that reaches the planner.
        let assessments: [CreditTimingCardAssessment] = [
            Self.assessment(ruling: .payDownBeforeClose, band: .elevated),
            Self.assessment(
                id: "b",
                ruling: .payDownBeforeClose,
                utilization: 0.7,
                band: .high,
                balance: 7_000,
                paydownTo30: 4_000,
                paydownTo10: 6_000
            ),
            Self.assessment(
                id: "c",
                ruling: .nearLimitAvoidMoreSpend,
                utilization: 0.95,
                band: .nearLimit,
                balance: 9_500,
                paydownTo30: 6_500,
                paydownTo10: 8_500
            ),
        ]
        let plan = CreditPaymentAllocationPlanner.plan(
            assessments: assessments,
            now: Self.now
        )
        for line in plan.groups.flatMap(\.lines) {
            inspected.append(line.reason)
        }

        for phrase in bannedPhrases {
            for copy in inspected {
                #expect(
                    !copy.localizedStandardContains(phrase),
                    "Banned phrase '\(phrase)' found in allocator copy: \(copy)"
                )
            }
        }
    }
}
