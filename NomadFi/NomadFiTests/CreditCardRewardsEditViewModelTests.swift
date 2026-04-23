// CreditCardRewardsEditViewModelTests.swift
// NomadFi
//
// Focused coverage for `CreditCardRewardsEditViewModel`:
//
//   - Initial bindings reflect the persisted reward profile.
//   - `save()` round-trips every field onto the `Account`.
//   - `markVerifiedToday()` is a no-op when no source is attached.
//   - `markVerifiedToday()` stamps the verification date and
//     promotes confidence to `.verifiedPrimary` when a source exists.
//   - `clearRewards()` + `save()` wipes every reward field so the
//     editor can be used to remove a previously saved profile.
//
// These tests construct `Account` directly — no SwiftData container
// is needed because the VM mutates the model in place and the
// helpers are pure. Keeps the suite fast and off the SwiftData
// parallel-init risk class.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct CreditCardRewardsEditViewModelTests {

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

    nonisolated private static let now = date(year: 2026, month: 4, day: 23)

    private static func creditCard(
        rewardProgramName: String? = nil,
        rewardUnit: RewardUnit? = nil,
        baseRewardRate: Double? = nil,
        categoryOverrides: [MerchantCategory: Double] = [:],
        sourceName: String? = nil,
        sourceURL: String? = nil,
        sourceConfidence: SourceConfidence? = nil,
        sourceVerifiedAt: Date? = nil
    ) -> Account {
        Account(
            name: "Sample Rewards",
            institutionName: "Example Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            rewardProgramName: rewardProgramName,
            rewardUnit: rewardUnit,
            baseRewardRate: baseRewardRate,
            rewardCategoryOverrides: categoryOverrides,
            rewardSourceName: sourceName,
            rewardSourceURL: sourceURL,
            rewardSourceConfidence: sourceConfidence,
            rewardSourceVerifiedAt: sourceVerifiedAt
        )
    }

    private static func makeViewModel(
        account: Account
    ) -> CreditCardRewardsEditViewModel {
        CreditCardRewardsEditViewModel(
            account: account,
            clock: { now }
        )
    }

    // MARK: - Init

    @Test("Initial bindings reflect the persisted reward profile")
    func initReflectsPersistedProfile() {
        let account = Self.creditCard(
            rewardProgramName: "Freedom Rise",
            rewardUnit: .cashBackPercent,
            baseRewardRate: 1.5,
            categoryOverrides: [.groceries: 3.0],
            sourceName: "Issuer product page",
            sourceURL: "https://example.com/card",
            sourceConfidence: .verifiedPrimary,
            sourceVerifiedAt: Self.date(year: 2026, month: 4, day: 1)
        )
        let vm = Self.makeViewModel(account: account)

        #expect(vm.programName == "Freedom Rise")
        #expect(vm.unit == .cashBackPercent)
        #expect(vm.baseRateText == "1.5")
        #expect(vm.categoryOverrideTexts[.groceries] == "3.0")
        #expect(vm.categoryOverrideTexts[.dining] == "")
        #expect(vm.sourceName == "Issuer product page")
        #expect(vm.sourceURL == "https://example.com/card")
        #expect(vm.sourceConfidence == .verifiedPrimary)
        #expect(vm.hasSource)
        #expect(vm.hasAnyRateEntered)
    }

    // MARK: - Save

    @Test("save() round-trips every field onto the Account")
    func saveWritesEveryFieldBackToAccount() {
        let account = Self.creditCard()
        let vm = Self.makeViewModel(account: account)

        vm.programName = "Cobalt"
        vm.unit = .pointsPerDollar
        vm.baseRateText = "1"
        vm.categoryOverrideTexts[.dining] = "5"
        vm.categoryOverrideTexts[.groceries] = "5"
        vm.sourceName = "Cobalt benefits page"
        vm.sourceURL = "https://example.com/cobalt"
        vm.sourceConfidence = .verifiedPrimary
        vm.sourceVerifiedAt = Self.now
        vm.notes = "Limits may apply per cycle."

        vm.save()

        #expect(account.rewardProgramName == "Cobalt")
        #expect(account.rewardUnitRawValue == RewardUnit.pointsPerDollar.rawValue)
        #expect(account.baseRewardRate == 1)

        let decodedOverrides = RewardProfile.decodedCategoryOverrides(
            account.rewardCategoryOverridesRaw
        )
        #expect(decodedOverrides[.dining] == 5)
        #expect(decodedOverrides[.groceries] == 5)

        #expect(account.rewardSourceName == "Cobalt benefits page")
        #expect(account.rewardSourceURL == "https://example.com/cobalt")
        #expect(account.rewardSourceConfidenceRaw == SourceConfidence.verifiedPrimary.rawValue)
        #expect(account.rewardSourceVerifiedAt == Self.now)
        #expect(account.rewardSourceNotes == "Limits may apply per cycle.")
    }

    @Test("Empty rate fields don't persist zero — they clear the stored value")
    func emptyFieldsClearStoredValue() {
        let account = Self.creditCard(
            rewardProgramName: "Legacy",
            rewardUnit: .cashBackPercent,
            baseRewardRate: 2.0,
            categoryOverrides: [.dining: 4.0]
        )
        let vm = Self.makeViewModel(account: account)

        vm.baseRateText = ""
        vm.categoryOverrideTexts[.dining] = ""
        vm.save()

        #expect(account.baseRewardRate == nil)
        #expect(account.rewardCategoryOverridesRaw == nil)
    }

    // MARK: - Mark verified

    @Test("markVerifiedToday does nothing when no source is attached")
    func markVerifiedIsNoOpWithoutSource() {
        let account = Self.creditCard()
        let vm = Self.makeViewModel(account: account)
        vm.sourceConfidence = .userProvided

        vm.markVerifiedToday()

        #expect(vm.sourceVerifiedAt == nil)
        #expect(vm.sourceConfidence == .userProvided)
    }

    @Test("markVerifiedToday stamps the date and promotes confidence when a source is attached")
    func markVerifiedStampsAndPromotes() {
        let account = Self.creditCard()
        let vm = Self.makeViewModel(account: account)
        vm.sourceName = "Issuer page"
        vm.sourceConfidence = .userProvided

        vm.markVerifiedToday()

        #expect(vm.sourceVerifiedAt == Self.now)
        #expect(vm.sourceConfidence == .verifiedPrimary)
    }

    @Test("markVerifiedToday preserves existing verified-primary confidence")
    func markVerifiedDoesNotDowngradeVerifiedSecondary() {
        let account = Self.creditCard(sourceName: "Page")
        let vm = Self.makeViewModel(account: account)
        vm.sourceConfidence = .verifiedSecondary

        vm.markVerifiedToday()

        #expect(vm.sourceVerifiedAt == Self.now)
        #expect(vm.sourceConfidence == .verifiedSecondary)
    }

    // MARK: - Clear

    @Test("clearRewards() + save() wipes every persisted reward field")
    func clearAndSaveRemovesEveryField() {
        let account = Self.creditCard(
            rewardProgramName: "Program",
            rewardUnit: .cashBackPercent,
            baseRewardRate: 2.0,
            categoryOverrides: [.dining: 4.0],
            sourceName: "Page",
            sourceURL: "https://example.com",
            sourceConfidence: .verifiedPrimary,
            sourceVerifiedAt: Self.now
        )
        let vm = Self.makeViewModel(account: account)

        vm.clearRewards()
        vm.save()

        #expect(account.rewardProgramName == nil)
        #expect(account.rewardUnitRawValue == nil)
        #expect(account.baseRewardRate == nil)
        #expect(account.rewardCategoryOverridesRaw == nil)
        #expect(account.rewardSourceName == nil)
        #expect(account.rewardSourceURL == nil)
        #expect(account.rewardSourceVerifiedAt == nil)
        #expect(account.rewardSourceNotes == nil)
    }
}
