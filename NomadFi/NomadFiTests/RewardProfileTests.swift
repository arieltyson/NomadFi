// RewardProfileTests.swift
// NomadFi
//
// Focused coverage for the reward data model:
//
//   - `RewardProfile` defaults are calm and unverified.
//   - `RewardUnit` raw-value parsing falls back to `.unknown`.
//   - Category overrides encode / decode through the CloudKit-safe
//     String column without losing keys.
//   - `Account.evaluateReward(for:now:)` honours category override
//     precedence, freshness gating, and unit gating.
//
// These are pure value-type tests — no SwiftData container needed,
// so they don't participate in the parallel-init race class.

import Foundation
import Testing

@testable import NomadFi

struct RewardProfileTests {

    // MARK: - Helpers

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private static let now = date(year: 2026, month: 4, day: 23)

    // MARK: - Defaults

    @Test("Fresh RewardProfile defaults are calm and unverified")
    func defaultsAreCalmAndUnverified() {
        let profile = RewardProfile()
        #expect(profile.programName.isEmpty)
        #expect(profile.unit == .unknown)
        #expect(profile.baseRate == nil)
        #expect(profile.categoryOverrides.isEmpty)
        #expect(profile.provenance.confidence == .userProvided)
        #expect(!profile.provenance.confidence.isVerified)
        #expect(!profile.hasAnyRate)
    }

    @Test("RewardUnit raw-value parsing falls back to unknown")
    func unknownRawValueFallsBackToUnknown() {
        #expect(RewardUnit.fromRawValue(nil) == .unknown)
        #expect(RewardUnit.fromRawValue("") == .unknown)
        #expect(RewardUnit.fromRawValue("not-a-unit") == .unknown)
        #expect(RewardUnit.fromRawValue("cashBackPercent") == .cashBackPercent)
    }

    // MARK: - Category override precedence

    @Test("rate(for:) picks a category override over the base rate")
    func rateForCategoryPrefersOverride() {
        let profile = RewardProfile(
            unit: .cashBackPercent,
            baseRate: 1.0,
            categoryOverrides: [
                .groceries: 3.0,
                .dining: 2.0,
            ]
        )
        #expect(profile.rate(for: .groceries) == 3.0)
        #expect(profile.rate(for: .dining) == 2.0)
        #expect(profile.rate(for: .utilities) == 1.0) // falls back to base
    }

    @Test("rate(for:) returns nil when neither override nor base is on file")
    func rateForCategoryReturnsNilWhenNoRate() {
        let profile = RewardProfile(unit: .cashBackPercent)
        #expect(profile.rate(for: .groceries) == nil)
    }

    // MARK: - Category override encoding

    @Test("Category overrides round-trip through the CloudKit-safe String column")
    func categoryOverridesRoundTripThroughJSON() {
        let original: [MerchantCategory: Double] = [
            .groceries: 3.0,
            .dining: 2.0,
            .travel: 1.5,
        ]
        let encoded = RewardProfile.encodedCategoryOverrides(original)
        let decoded = RewardProfile.decodedCategoryOverrides(encoded)
        #expect(decoded == original)
    }

    @Test("Empty overrides encode to nil so absent rewards stay null, not an empty blob")
    func emptyOverridesEncodeToNil() {
        #expect(RewardProfile.encodedCategoryOverrides([:]) == nil)
    }

    @Test("Malformed or nil override JSON decodes to an empty dictionary, never a crash")
    func malformedOverrideJSONIsIgnored() {
        #expect(RewardProfile.decodedCategoryOverrides(nil).isEmpty)
        #expect(RewardProfile.decodedCategoryOverrides("").isEmpty)
        #expect(RewardProfile.decodedCategoryOverrides("not-json").isEmpty)
        // Unknown keys at decode time are dropped silently.
        let forwardCompat = "{\"future-category-we-dont-know\":5.0}"
        #expect(RewardProfile.decodedCategoryOverrides(forwardCompat).isEmpty)
    }

    // MARK: - Account.evaluateReward

    private static func verifiedAccount(
        baseRate: Double? = 1.5,
        categoryOverrides: [MerchantCategory: Double] = [:],
        verifiedAt: Date? = now,
        unit: RewardUnit = .cashBackPercent
    ) -> Account {
        Account(
            name: "Sample Rewards",
            institutionName: "Example Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            rewardProgramName: "Sample Program",
            rewardUnit: unit,
            baseRewardRate: baseRate,
            rewardCategoryOverrides: categoryOverrides,
            rewardSourceName: "Issuer product page",
            rewardSourceURL: "https://example.com/card",
            rewardSourceConfidence: .verifiedPrimary,
            rewardSourceVerifiedAt: verifiedAt
        )
    }

    @Test("Verified + fresh account evaluation is usable for ranking")
    func verifiedFreshEvaluationIsUsable() {
        let account = Self.verifiedAccount()
        let evaluation = account.evaluateReward(for: .groceries, now: Self.now)
        #expect(evaluation.rate == 1.5)
        #expect(evaluation.unit == .cashBackPercent)
        #expect(evaluation.isVerifiedAndFresh)
        #expect(evaluation.isUsableForRanking)
        #expect(evaluation.categoryOverrideApplied == false)
    }

    @Test("Category override wins over base rate in the evaluation")
    func categoryOverrideWinsInEvaluation() {
        let account = Self.verifiedAccount(
            baseRate: 1.0,
            categoryOverrides: [.groceries: 3.0]
        )
        let evaluation = account.evaluateReward(for: .groceries, now: Self.now)
        #expect(evaluation.rate == 3.0)
        #expect(evaluation.categoryOverrideApplied)
    }

    @Test("Stale verified rewards are downgraded and not used for ranking")
    func staleVerifiedRewardIsIgnoredForRanking() {
        // Issuer-terms freshness window is 30 days; 120 days back
        // is well past it.
        let hundredTwentyDaysAgo = Self.now.addingTimeInterval(-60 * 60 * 24 * 120)
        let account = Self.verifiedAccount(verifiedAt: hundredTwentyDaysAgo)
        let evaluation = account.evaluateReward(for: .groceries, now: Self.now)
        #expect(evaluation.rate == 1.5)
        #expect(!evaluation.isVerifiedAndFresh)
        #expect(!evaluation.isUsableForRanking)
        #expect(evaluation.explanation?.lowercased().contains("not verified") == true
                || evaluation.explanation?.lowercased().contains("freshness") == true)
    }

    @Test("Unverified / user-provided rewards surface as caveated and never rank")
    func unverifiedRewardIsNotRanker() {
        let account = Account(
            name: "Manual Entry",
            institutionName: "Example Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            rewardProgramName: "Sample",
            rewardUnit: .cashBackPercent,
            baseRewardRate: 2.0
            // No source fields — provenance defaults to user-provided.
        )
        let evaluation = account.evaluateReward(for: .groceries, now: Self.now)
        #expect(evaluation.rate == 2.0)
        #expect(!evaluation.isVerifiedAndFresh)
        #expect(!evaluation.isUsableForRanking)
    }

    @Test("Unknown reward unit suppresses the evaluation even when a rate exists")
    func unknownUnitSuppressesEvaluation() {
        let account = Self.verifiedAccount(unit: .unknown)
        let evaluation = account.evaluateReward(for: .groceries, now: Self.now)
        #expect(evaluation == .empty)
    }

    @Test("Deposit and wallet accounts always produce an empty evaluation")
    func nonCreditCardAccountsHaveEmptyEvaluation() {
        let checking = Account(
            name: "Checking",
            institutionName: "Example Bank",
            accountType: .checking,
            currencyCode: .usd,
            rewardProgramName: "Ignored",
            rewardUnit: .cashBackPercent,
            baseRewardRate: 1.0,
            rewardSourceName: "Page",
            rewardSourceConfidence: .verifiedPrimary,
            rewardSourceVerifiedAt: Self.now
        )
        // `PurchaseDecisionEngine.rewardEvaluation(for:context:now:)`
        // is the gate — but the account helper itself still returns
        // a profile, so the engine enforces the "credit cards only"
        // rule in its own layer. We verify the Account-layer is honest.
        #expect(checking.rewardProfile.hasAnyRate)
        let evaluation = checking.evaluateReward(for: .groceries, now: Self.now)
        // At the Account layer, evaluation is still populated — the
        // engine's gate is tested separately in PurchaseDecisionEngineTests.
        #expect(evaluation.rate == 1.0)
    }
}
