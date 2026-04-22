// CreditTimingDecisionEngineTests.swift
// NomadFi
//
// Pure-logic coverage for the Credit Timing engine. These tests pin
// every claim NomadFi makes on the brief sheet and every claim it
// refuses to make:
//
//   - Missing inputs (no cards, no limit, no balance) never produce a
//     strong ruling.
//   - A stale snapshot never produces a strong ruling.
//   - An unconfirmed schedule never produces a strong ruling.
//   - Low-utilization cards yield `.readyNoUrgentAction`.
//   - Elevated-utilization cards yield `.payDownBeforeClose` and
//     compute the paydown-to-30% amount.
//   - Near-limit cards yield `.nearLimitAvoidMoreSpend`.
//   - Nil balance is never treated as zero.
//   - Absolute-date phrasing only — no relative language.
//   - Copy never contains "guarantee", "score will increase", or
//     "carry a balance".
//   - `DecisionCatalog` exposes Amazon + Credit Timing with distinct
//     summaries.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct CreditTimingDecisionEngineTests {

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

    private static let now = date(year: 2026, month: 4, day: 22)

    /// Builds a credit-card account with a confirmed schedule and a
    /// fresh user-entered snapshot by default. Individual tests
    /// override whatever they want to vary.
    private func makeCreditCard(
        name: String = "Sample Rewards",
        institution: String = "Example Bank",
        creditLimit: Double? = 10_000,
        currentBalance: Double? = 1_500,
        snapshotUpdatedAt: Date? = CreditTimingDecisionEngineTests.now,
        snapshotSource: FinancialSnapshotSource = .userSnapshot,
        statementPeriodStart: Date? = CreditTimingDecisionEngineTests.date(year: 2026, month: 4, day: 1),
        statementClose: Date? = CreditTimingDecisionEngineTests.date(year: 2026, month: 4, day: 28),
        paymentDue: Date? = CreditTimingDecisionEngineTests.date(year: 2026, month: 5, day: 25),
        scheduleConfirmedAt: Date? = CreditTimingDecisionEngineTests.date(year: 2026, month: 4, day: 21)
    ) -> Account {
        Account(
            name: name,
            institutionName: institution,
            accountType: .creditCard,
            currencyCode: .usd,
            statementPeriodStartDate: statementPeriodStart,
            statementClosingDate: statementClose,
            paymentDueDate: paymentDue,
            statementScheduleLastConfirmedAt: scheduleConfirmedAt,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            financialSnapshotUpdatedAt: snapshotUpdatedAt,
            financialSnapshotSource: snapshotSource
        )
    }

    private func makeCheckingAccount() -> Account {
        Account(
            name: "Checking",
            institutionName: "Example Bank",
            accountType: .checking,
            currencyCode: .usd,
            creditLimit: nil,
            currentBalance: 3_000
        )
    }

    // MARK: - No credit cards on file

    @Test("No credit cards on file yields the setup prompt and a noCreditCardsOnFile ruling")
    func noCreditCardsYieldsSetupPrompt() {
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [makeCheckingAccount()],
            now: Self.now
        )
        #expect(decision.ruling == .noCreditCardsOnFile)
        #expect(decision.cardAssessments.isEmpty)
        #expect(decision.missingDataChecklist.count == 1)
        #expect(
            decision.missingDataChecklist.first?
                .localizedStandardContains("Add a credit-card account") == true
        )
    }

    // MARK: - Missing profile data

    @Test("Missing credit limit blocks strong recommendation with .needsSetup")
    func missingLimitBlocksRuling() {
        let account = makeCreditCard(creditLimit: nil)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .needsSetup)
        #expect(assessment.utilization == nil)
        #expect(assessment.paydownTargetTo30Percent == nil)
        #expect(decision.ruling == .missingData)
    }

    @Test("Missing current balance blocks strong recommendation and never defaults to zero")
    func missingBalanceNeverZero() {
        let account = makeCreditCard(currentBalance: nil)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .needsSetup)
        #expect(assessment.utilization == nil)
        #expect(assessment.utilizationBand == nil)
        // And utilization must never be the false "0 / limit = 0%".
        let formatted = assessment.utilization?.description ?? ""
        #expect(!formatted.contains("0.0"))
    }

    // MARK: - Staleness

    @Test("Stale snapshot blocks strong recommendation")
    func staleSnapshotBlocksRuling() {
        // userSnapshot freshness window is 7 days; pick an update 30
        // days old so the engine must mark the snapshot stale.
        let thirtyDaysAgo = Self.now.addingTimeInterval(-60 * 60 * 24 * 30)
        let account = makeCreditCard(
            currentBalance: 1_500,
            snapshotUpdatedAt: thirtyDaysAgo
        )
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .snapshotStale)
        #expect(assessment.snapshotIsStale)
    }

    // MARK: - Schedule

    @Test("Unconfirmed schedule blocks strong recommendation")
    func unconfirmedScheduleBlocksRuling() {
        let account = makeCreditCard(scheduleConfirmedAt: nil)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .scheduleMissing)
        #expect(assessment.scheduleState != .confirmed)
    }

    // MARK: - Low utilization

    @Test("Low utilization yields readyNoUrgentAction and no paydown amount")
    func lowUtilizationIsReady() {
        // 500 / 10_000 = 5%
        let account = makeCreditCard(creditLimit: 10_000, currentBalance: 500)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .readyNoUrgentAction)
        #expect(assessment.utilizationBand == .low)
        // Already below both thresholds — no paydown to report.
        #expect(assessment.paydownTargetTo30Percent == nil)
        #expect(assessment.paydownTargetTo10Percent == nil)
        #expect(decision.ruling == .allCardsReady)
    }

    // MARK: - Elevated utilization

    @Test("Elevated utilization yields payDownBeforeClose and a paydown-to-30% amount")
    func elevatedUtilizationComputesPaydown() {
        // 5_000 / 10_000 = 50%
        let account = makeCreditCard(creditLimit: 10_000, currentBalance: 5_000)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .payDownBeforeClose)
        #expect(assessment.utilizationBand == .elevated)
        // Paydown to 30% target: 5000 - 3000 = 2000.
        let paydown30 = try! #require(assessment.paydownTargetTo30Percent)
        #expect(abs(paydown30 - 2_000) < 0.001)
        // Paydown to 10% target: 5000 - 1000 = 4000.
        let paydown10 = try! #require(assessment.paydownTargetTo10Percent)
        #expect(abs(paydown10 - 4_000) < 0.001)
        #expect(decision.ruling == .somePayDownBeforeClose)
    }

    // MARK: - Near limit

    @Test("Near-limit utilization yields nearLimitAvoidMoreSpend")
    func nearLimitYieldsAvoidMoreSpend() {
        // 9_500 / 10_000 = 95%
        let account = makeCreditCard(creditLimit: 10_000, currentBalance: 9_500)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let assessment = try! #require(decision.cardAssessments.first)
        #expect(assessment.ruling == .nearLimitAvoidMoreSpend)
        #expect(assessment.utilizationBand == .nearLimit)
        #expect(decision.ruling == .someNearLimit)
    }

    // MARK: - Severity ordering

    @Test("Severity ordering surfaces near-limit before paydown and ready")
    func severityOrderingIsCorrect() {
        let ready = makeCreditCard(
            name: "Ready",
            creditLimit: 10_000,
            currentBalance: 500
        )
        let paydown = makeCreditCard(
            name: "Paydown",
            creditLimit: 10_000,
            currentBalance: 5_000
        )
        let nearLimit = makeCreditCard(
            name: "NearLimit",
            creditLimit: 10_000,
            currentBalance: 9_500
        )
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [ready, paydown, nearLimit],
            now: Self.now
        )
        #expect(decision.cardAssessments.count == 3)
        #expect(decision.cardAssessments.map(\.ruling) == [
            .nearLimitAvoidMoreSpend,
            .payDownBeforeClose,
            .readyNoUrgentAction,
        ])
        #expect(decision.ruling == .someNearLimit)
    }

    // MARK: - Non-credit accounts ignored

    @Test("Non-credit accounts are ignored by the engine")
    func nonCreditAccountsIgnored() {
        let credit = makeCreditCard()
        let checking = makeCheckingAccount()
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [checking, credit],
            now: Self.now
        )
        #expect(decision.cardAssessments.count == 1)
        #expect(decision.cardAssessments.first?.accountName == credit.name)
    }

    // MARK: - Copy safety

    @Test("Engine copy never uses prohibited score / debt phrases")
    func copyAvoidsProhibitedPhrases() {
        let prohibited = [
            "guarantee",
            "guaranteed",
            "score will increase",
            "will improve your score",
            "carry a balance",
        ]
        // Survey every surface the engine can emit: hard rules, ruling
        // summaries, per-card ruling labels + accessibility, band
        // labels.
        var surfaces: [String] = CreditTimingDecisionEngine.hardRules
        surfaces.append(contentsOf: CreditTimingRuling.allCases.map(\.displaySummary))
        surfaces.append(contentsOf: CreditTimingCardRuling.allCases.map(\.displayLabel))
        surfaces.append(contentsOf: CreditTimingCardRuling.allCases.map(\.accessibilityLabel))
        surfaces.append(contentsOf: CreditTimingUtilizationBand.allCases.map(\.displayLabel))
        surfaces.append(contentsOf: CreditTimingUtilizationBand.allCases.map(\.accessibilityLabel))

        for text in surfaces {
            let lower = text.lowercased()
            for phrase in prohibited {
                #expect(
                    !lower.contains(phrase),
                    "Surface text must not contain \"\(phrase)\": \(text)"
                )
            }
        }
    }

    @Test("Hard rules explicitly pin the pay-in-full / no-carry and absolute-date promises")
    func hardRulesPinKeyClaims() {
        let joined = CreditTimingDecisionEngine.hardRules
            .joined(separator: "\n")
            .lowercased()
        #expect(joined.contains("pay at least the statement balance"))
        #expect(joined.contains("never recommends carrying a balance"))
        #expect(joined.contains("absolute dates"))
        #expect(joined.contains("multi-factor"))
    }

    @Test("Per-card checklist copy uses absolute-date-friendly wording and no relative phrases")
    func checklistUsesAbsoluteDateFriendlyWording() {
        let account = makeCreditCard(
            creditLimit: nil,
            currentBalance: nil,
            scheduleConfirmedAt: nil
        )
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [account],
            now: Self.now
        )
        let relativePhrases = [
            "tomorrow",
            "in a few days",
            "soon",
            "shortly",
            "today",
            "yesterday",
        ]
        for item in decision.missingDataChecklist {
            let lower = item.lowercased()
            for phrase in relativePhrases {
                #expect(
                    !lower.contains(phrase),
                    "Checklist must not use relative phrasing \"\(phrase)\": \(item)"
                )
            }
        }
    }

    // MARK: - Catalog surface

    @Test("DecisionCatalog exposes Amazon arrival and Credit timing with distinct summaries")
    func catalogExposesBothDecisionsWithDistinctSummaries() {
        let all = DecisionCatalog.all
        #expect(all.map(\.id) == [.amazonArrivalOrder, .creditTimingCheck])

        let summaries = Set(all.map(\.summary))
        #expect(summaries.count == all.count)

        let titles = Set(all.map(\.title))
        #expect(titles.count == all.count)
    }

    // MARK: - Citations

    @Test("Citations include CFPB and myFICO entries")
    func citationsAnchorCFPBAndMyFICO() {
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [makeCreditCard()],
            now: Self.now
        )
        let publishers = Set(decision.citations.map(\.publisher))
        #expect(publishers.contains("CFPB"))
        #expect(publishers.contains("myFICO"))
        for citation in decision.citations {
            #expect(citation.evidence == .officialSource)
        }
    }
}
