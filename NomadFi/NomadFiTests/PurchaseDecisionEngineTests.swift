// PurchaseDecisionEngineTests.swift
// NomadFi
//
// Pure-logic coverage for the generic purchase engine. These tests
// pin every claim NomadFi makes on the brief sheet and every claim
// it refuses to make:
//
//   - Missing context (no amount) never produces a recommendation.
//   - No payment accounts on file yields `.noPaymentAccountsOnFile`.
//   - Investment accounts are never a payment method.
//   - Credit cards missing limit or current balance are `.needsSetup`.
//   - Stale snapshots block strong recommendations.
//   - Insufficient available credit blocks a credit-card candidate.
//   - Debit/wallet with sufficient same-currency balance beats a
//     credit card on a same-currency purchase (no rewards ranking).
//   - Currency mismatch surfaces FX verification even when the FX
//     fee value on the account is non-zero; unverified fees stay
//     unverified.
//   - Rewards are never used for ranking in v1 — category only
//     triggers a consolidated "verify rewards" checklist entry.
//   - Nil balances are never silently treated as zero.
//   - Hard rules and copy never contain prohibited phrases.
//   - Catalog now ships Amazon + Credit Timing + Purchase Card Check.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PurchaseDecisionEngineTests {

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

    private func baseContext(
        amount: Double? = 80,
        currency: CurrencyCode = .usd,
        category: MerchantCategory = .groceries,
        merchant: String = "Target",
        country: String = "San Francisco"
    ) -> PurchaseContext {
        PurchaseContext(
            merchantName: merchant,
            category: category,
            amount: amount,
            currencyCode: currency,
            countryCode: country,
            timingText: ""
        )
    }

    private func checkingAccount(
        name: String = "Chase Checking",
        institution: String = "Chase",
        currency: CurrencyCode = .usd,
        balance: Double? = 500
    ) -> Account {
        Account(
            name: name,
            institutionName: institution,
            accountType: .checking,
            currencyCode: currency,
            currentBalance: balance
        )
    }

    private func creditCard(
        name: String = "Rewards Card",
        institution: String = "Issuer Bank",
        currency: CurrencyCode = .usd,
        creditLimit: Double? = 5_000,
        currentBalance: Double? = 500,
        snapshotUpdatedAt: Date? = PurchaseDecisionEngineTests.now,
        snapshotSource: FinancialSnapshotSource = .userSnapshot,
        foreignTransactionFeePercent: Double = 0,
        statementPeriodStart: Date? = PurchaseDecisionEngineTests.date(year: 2026, month: 4, day: 1),
        statementClose: Date? = PurchaseDecisionEngineTests.date(year: 2026, month: 4, day: 28),
        paymentDue: Date? = PurchaseDecisionEngineTests.date(year: 2026, month: 5, day: 25),
        scheduleConfirmedAt: Date? = PurchaseDecisionEngineTests.date(year: 2026, month: 4, day: 21)
    ) -> Account {
        Account(
            name: name,
            institutionName: institution,
            accountType: .creditCard,
            currencyCode: currency,
            foreignTransactionFeePercent: foreignTransactionFeePercent,
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

    private func investmentAccount() -> Account {
        Account(
            name: "Brokerage",
            institutionName: "Investment Bank",
            accountType: .investment,
            currencyCode: .usd,
            currentBalance: 10_000
        )
    }

    // MARK: - Context gating

    @Test("Missing purchase amount never produces a recommendation")
    func missingAmountBlocksRecommendation() {
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: nil),
            accounts: [checkingAccount()],
            now: Self.now
        )
        #expect(decision.ruling == .needsPurchaseContext)
        #expect(decision.recommendation == nil)
        #expect(decision.fallback == nil)
    }

    @Test("Zero-amount purchase still blocks recommendation")
    func zeroAmountBlocksRecommendation() {
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 0),
            accounts: [checkingAccount()],
            now: Self.now
        )
        #expect(decision.ruling == .needsPurchaseContext)
        #expect(decision.recommendation == nil)
    }

    // MARK: - No accounts

    @Test("No payment accounts on file yields .noPaymentAccountsOnFile")
    func noAccountsYieldsNoPaymentAccounts() {
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [],
            now: Self.now
        )
        #expect(decision.ruling == .noPaymentAccountsOnFile)
        #expect(decision.recommendation == nil)
    }

    @Test("Only an investment account still yields .noPaymentAccountsOnFile")
    func onlyInvestmentYieldsNoPaymentAccounts() {
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [investmentAccount()],
            now: Self.now
        )
        #expect(decision.ruling == .noPaymentAccountsOnFile)
        #expect(decision.candidates.count == 1)
        #expect(decision.candidates.first?.stance == .excludedInvestment)
    }

    // MARK: - Credit card setup gates

    @Test("Credit card missing creditLimit is .needsSetup and blocks recommendation")
    func creditCardMissingLimitIsNeedsSetup() {
        let card = creditCard(creditLimit: nil)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [card],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(assessment.stance == .needsSetup)
        #expect(assessment.availableCredit == nil)
        #expect(decision.recommendation == nil)
    }

    @Test("Credit card missing currentBalance is .needsSetup — nil is never zero")
    func creditCardMissingBalanceIsNeedsSetup() {
        let card = creditCard(currentBalance: nil)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [card],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(assessment.stance == .needsSetup)
        #expect(assessment.availableCredit == nil)
        // Even though limit is known, NomadFi refuses to pretend
        // balance is zero.
        #expect(!(assessment.availableCredit ?? -1).isFinite ? false : assessment.availableCredit == nil)
    }

    // MARK: - Staleness

    @Test("Stale credit snapshot blocks strong recommendation")
    func staleCreditSnapshotCaveated() {
        let thirtyDaysAgo = Self.now.addingTimeInterval(-60 * 60 * 24 * 30)
        let card = creditCard(snapshotUpdatedAt: thirtyDaysAgo)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [card],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(assessment.stance == .snapshotStale)
        #expect(decision.recommendation == nil)
    }

    // MARK: - Coverage

    @Test("Insufficient available credit blocks a credit-card candidate")
    func insufficientAvailableCreditBlocksCard() {
        let card = creditCard(creditLimit: 100, currentBalance: 95)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 200),
            accounts: [card],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(assessment.stance == .insufficientCreditCoverage)
        #expect(decision.recommendation == nil)
    }

    @Test("Insufficient deposit balance blocks a debit/checking candidate")
    func insufficientDepositBalanceBlocks() {
        let checking = checkingAccount(balance: 50)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 200),
            accounts: [checking],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(assessment.stance == .insufficientFunds)
        #expect(decision.recommendation == nil)
    }

    // MARK: - Ranking and preferences

    @Test("Debit account with sufficient same-currency balance is preferred over a credit card for the same purchase")
    func debitPreferredOverCredit() {
        let checking = checkingAccount(balance: 500)
        let card = creditCard()
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80),
            accounts: [checking, card],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        #expect(!recommendation.isCreditCard)
        #expect(recommendation.accountName == "Chase Checking")
        let fallback = try! #require(decision.fallback)
        #expect(fallback.isCreditCard)
    }

    @Test("Same-currency candidates are preferred over cross-currency ones")
    func sameCurrencyPreferredOverCrossCurrency() {
        let usdChecking = checkingAccount(
            name: "USD Checking",
            currency: .usd,
            balance: 500
        )
        let cadChecking = checkingAccount(
            name: "CAD Checking",
            currency: .cad,
            balance: 5_000
        )
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, currency: .usd),
            accounts: [cadChecking, usdChecking],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.accountName == "USD Checking")
        #expect(recommendation.matchesPurchaseCurrency)
    }

    // MARK: - FX verification

    @Test("Currency mismatch produces an FX verification check")
    func currencyMismatchProducesFXCheck() {
        let cadCard = creditCard(currency: .cad, foreignTransactionFeePercent: 2.5)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, currency: .usd),
            accounts: [cadCard],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(!assessment.matchesPurchaseCurrency)
        #expect(assessment.foreignTransactionFeePercent == 2.5)
        // The fee exists on the account but its provenance isn't
        // marked verified — so the engine must keep it unverified.
        #expect(!assessment.foreignTransactionFeeIsVerified)

        let joinedChecks = decision.missingDataChecklist.joined(separator: "\n")
        #expect(joinedChecks.localizedStandardContains("foreign-currency conversion"))
    }

    @Test("Unverified FX fee stays unverified — never gets a 'verified' label")
    func unverifiedFXStaysUnverified() {
        let card = creditCard(currency: .cad, foreignTransactionFeePercent: 2.5)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, currency: .usd),
            accounts: [card],
            now: Self.now
        )
        let assessment = try! #require(decision.candidates.first)
        #expect(!assessment.foreignTransactionFeeIsVerified)

        // The reason copy must say "needs verification" so the UI
        // can render a caveat badge.
        let joinedReasons = assessment.reasons.joined(separator: "\n")
        #expect(joinedReasons.localizedStandardContains("needs verification"))
    }

    // MARK: - Rewards

    @Test("Unverified rewards card still loses to a same-currency debit — rewards don't rank without a verified source")
    func unverifiedRewardsDoNotOutrankDebit() {
        let creditWithBonus = creditCard(
            name: "Dining Rewards",
            institution: "Generic Bank"
        )
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .dining),
            accounts: [creditWithBonus, checking],
            now: Self.now
        )
        // Nominal "dining" card name is not a verified source;
        // deposit keeps the top spot.
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.accountName == "Chase Checking")

        // Rewards-sensitive category without any verified rate
        // surfaces the umbrella reminder so the user can record one.
        let joined = decision.missingDataChecklist.joined(separator: "\n")
        #expect(joined.localizedStandardContains("Dining"))
        #expect(joined.localizedStandardContains("Rewards Terms"))
    }

    @Test("Non-rewards-sensitive category does not add the umbrella rewards reminder")
    func generalCategorySkipsRewardsReminder() {
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .general),
            accounts: [checking],
            now: Self.now
        )
        let joined = decision.missingDataChecklist.joined(separator: "\n")
        #expect(!joined.localizedStandardContains("rewards"))
    }

    // MARK: - Verified rewards (v2 behavior)

    private func verifiedRewardsCreditCard(
        name: String = "Verified Rewards Card",
        institution: String = "Verified Issuer",
        unit: RewardUnit = .cashBackPercent,
        baseRate: Double? = 2.0,
        categoryOverrides: [MerchantCategory: Double] = [:],
        limit: Double = 5_000,
        currentBalance: Double = 500,
        verifiedAt: Date? = PurchaseDecisionEngineTests.now,
        currency: CurrencyCode = .usd
    ) -> Account {
        Account(
            name: name,
            institutionName: institution,
            accountType: .creditCard,
            currencyCode: currency,
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: Self.date(year: 2026, month: 4, day: 21),
            creditLimit: limit,
            currentBalance: currentBalance,
            financialSnapshotUpdatedAt: Self.now,
            financialSnapshotSource: .userSnapshot,
            rewardProgramName: "Program",
            rewardUnit: unit,
            baseRewardRate: baseRate,
            rewardCategoryOverrides: categoryOverrides,
            rewardSourceName: "Issuer product page",
            rewardSourceURL: "https://example.com/card",
            rewardSourceConfidence: .verifiedPrimary,
            rewardSourceVerifiedAt: verifiedAt
        )
    }

    @Test("Verified cash-back credit card is promoted over a same-currency deposit when safety gates clear")
    func verifiedCashBackBeatsDeposit() {
        let verified = verifiedRewardsCreditCard(baseRate: 2.0)
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .general),
            accounts: [verified, checking],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.accountName == verified.name)
        #expect(recommendation.isCreditCard)
        #expect(recommendation.rewardEvaluation.isUsableForRanking)
    }

    @Test("Category override drives the quoted rate when it beats the base")
    func categoryOverrideDrivesRankingQuote() {
        let verified = verifiedRewardsCreditCard(
            baseRate: 1.0,
            categoryOverrides: [.groceries: 3.0]
        )
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .groceries),
            accounts: [verified, checkingAccount(balance: 500)],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.rewardEvaluation.rate == 3.0)
        #expect(recommendation.rewardEvaluation.categoryOverrideApplied)
    }

    @Test("Stale verified reward source is downgraded and the card does not win on rewards")
    func staleRewardSourceIsNotRanker() {
        // Issuer-terms freshness window is 30 days.
        let fourMonthsAgo = Self.now.addingTimeInterval(-60 * 60 * 24 * 120)
        let stale = verifiedRewardsCreditCard(
            baseRate: 3.0,
            verifiedAt: fourMonthsAgo
        )
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .general),
            accounts: [stale, checking],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        // Rewards were not trusted → debit keeps the top spot.
        #expect(recommendation.accountName == "Chase Checking")
        let staleAssessment = try! #require(
            decision.candidates.first { $0.accountName == stale.name }
        )
        #expect(!staleAssessment.rewardEvaluation.isVerifiedAndFresh)
        #expect(!staleAssessment.rewardEvaluation.isUsableForRanking)
    }

    @Test("Rewards never override insufficient credit coverage")
    func rewardsNeverOverrideInsufficientCoverage() {
        // Low-limit card with a verified high rate cannot cover the purchase.
        let tightVerified = verifiedRewardsCreditCard(
            name: "Tiny Limit Verified",
            baseRate: 5.0,
            limit: 50,
            currentBalance: 30
        )
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 100, category: .general),
            accounts: [tightVerified, checking],
            now: Self.now
        )
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.accountName == "Chase Checking")

        let tightAssessment = try! #require(
            decision.candidates.first { $0.accountName == tightVerified.name }
        )
        #expect(tightAssessment.stance == .insufficientCreditCoverage)
    }

    @Test("Incomparable reward units make rewards context-only — debit keeps the top spot")
    func incomparableUnitsFallBackToPreRewardRanking() {
        // Two credit cards: one in cash-back, one in points. Units
        // are incomparable → engine refuses to rank on rewards.
        let cashBack = verifiedRewardsCreditCard(
            name: "Cash Back Card",
            unit: .cashBackPercent,
            baseRate: 2.0
        )
        let points = verifiedRewardsCreditCard(
            name: "Points Card",
            institution: "Points Issuer",
            unit: .pointsPerDollar,
            baseRate: 3.0
        )
        let checking = checkingAccount(balance: 500)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .general),
            accounts: [cashBack, points, checking],
            now: Self.now
        )
        // With rewards unranked, the debit account wins by the
        // pre-rewards safety preference.
        let recommendation = try! #require(decision.recommendation)
        #expect(recommendation.accountName == "Chase Checking")
    }

    @Test("Umbrella rewards reminder disappears once at least one card has verified fresh rewards")
    func umbrellaReminderDisappearsWithVerifiedRate() {
        let verified = verifiedRewardsCreditCard(baseRate: 2.0)
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(amount: 80, category: .dining),
            accounts: [verified, checkingAccount(balance: 500)],
            now: Self.now
        )
        let joined = decision.missingDataChecklist.joined(separator: "\n")
        #expect(!joined.localizedStandardContains("Rewards Terms"))
    }

    // MARK: - Hard rules + copy safety

    @Test("Hard rules explicitly pin pay-in-full and no-carry-balance")
    func hardRulesPinCorePromises() {
        let joined = PurchaseDecisionEngine.hardRules
            .joined(separator: "\n")
            .lowercased()
        #expect(joined.contains("pay the statement balance in full"))
        #expect(joined.contains("never recommends carrying a balance"))
        #expect(joined.contains("any single purchase decision"))
        // Rewards invariant: only used when verified + comparable;
        // unverified/stale rates never drive ranking.
        #expect(joined.contains("verified source"))
        #expect(joined.contains("never drive ranking"))
    }

    @Test("Engine copy never uses prohibited score / guarantee / 'always best' phrases")
    func engineCopyHasNoProhibitedPhrases() {
        let prohibited = [
            "guaranteed",
            "score will increase",
            "always best",
            "carry a balance",
        ]
        var surfaces: [String] = PurchaseDecisionEngine.hardRules
        surfaces.append(
            contentsOf: PurchaseDecisionRuling.allCases.map(\.displaySummary)
        )
        surfaces.append(
            contentsOf: PurchaseCandidateStance.allCases.map(\.displayLabel)
        )
        surfaces.append(
            contentsOf: PurchaseCandidateStance.allCases.map(\.accessibilityLabel)
        )
        surfaces.append(
            contentsOf: MerchantCategory.allCases.map(\.displayLabel)
        )
        surfaces.append(
            contentsOf: MerchantCategory.allCases.map(\.accessibilityLabel)
        )

        for text in surfaces {
            let lower = text.lowercased()
            for phrase in prohibited {
                #expect(
                    !lower.contains(phrase),
                    "Surface must not contain \"\(phrase)\": \(text)"
                )
            }
        }
    }

    // MARK: - Catalog

    @Test("DecisionCatalog exposes Amazon, Credit Timing, and Purchase Card Check in that order with distinct summaries")
    func catalogOrderIsExpected() {
        let all = DecisionCatalog.all
        #expect(all.map(\.id) == [
            .amazonArrivalOrder,
            .creditTimingCheck,
            .purchaseCardCheck,
        ])
        let summaries = Set(all.map(\.summary))
        #expect(summaries.count == all.count)
        let titles = Set(all.map(\.title))
        #expect(titles.count == all.count)
    }

    // MARK: - Citations

    @Test("Citations are anchored on the cross-border purchase mission — CFPB / HelpWithMyBank / FCAC / Visa / Mastercard, no myFICO")
    func citationsAnchorCrossBorderPurchaseMission() {
        let decision = PurchaseDecisionEngine.decide(
            context: baseContext(),
            accounts: [checkingAccount()],
            now: Self.now
        )
        let publishers = Set(decision.citations.map(\.publisher))
        let required: Set<String> = [
            "CFPB",
            "HelpWithMyBank",
            "FCAC",
            "Visa",
            "Mastercard",
        ]
        #expect(
            required.isSubset(of: publishers),
            "Missing required cross-border purchase publishers: \(required.subtracting(publishers))"
        )
        // myFICO citations belong to the Credit Timing engine — they
        // are intentionally absent from the purchase brief now.
        #expect(!publishers.contains("myFICO"))
        for citation in decision.citations {
            #expect(citation.evidence == .officialSource)
        }
    }
}
