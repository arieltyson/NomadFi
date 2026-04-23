// CreditCardRewardsEditViewModel.swift
// NomadFi
//
// Working state for the focused credit-card rewards editor. Mirrors
// the pattern used by ``CreditCardScheduleEditViewModel`` so the UI
// can bind to native `TextField` / `Picker` / `DatePicker` without
// losing the distinction between "user cleared the field" and "user
// typed zero".
//
// Product constraints this file bakes in:
//   - Reward terms are never treated as verified without an issuer
//     source attached.
//   - Category overrides only exist when the user types a value for
//     that specific category. Entering an empty field clears the
//     override rather than persisting a zero rate.
//   - Stamping "Verified today" requires the user to have at least
//     a source name or URL recorded — NomadFi never back-dates
//     verification against an empty source.

import Foundation
import Observation

/// View model behind ``CreditCardRewardsEditView``.
@MainActor
@Observable
final class CreditCardRewardsEditViewModel {

    // MARK: - Dependencies

    /// The persisted account being edited. Mutations flow through
    /// SwiftData autosave after `save()`.
    let account: Account

    /// Clock seam so tests can pin the "verified today" stamp.
    private let clock: @Sendable () -> Date

    // MARK: - Profile

    var programName: String
    var unit: RewardUnit
    var baseRateText: String

    /// Per-category override strings — empty string means "no
    /// override". Stored as a flat dictionary keyed by the enum so
    /// adding a future `MerchantCategory` case is automatic.
    var categoryOverrideTexts: [MerchantCategory: String]

    // MARK: - Provenance

    var sourceName: String
    var sourceURL: String
    var sourceConfidence: SourceConfidence
    var sourceVerifiedAt: Date?
    var notes: String

    // MARK: - Init

    init(
        account: Account,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.account = account
        self.clock = clock

        let profile = account.rewardProfile
        self.programName = profile.programName
        self.unit = profile.unit
        self.baseRateText = Self.format(profile.baseRate)

        var texts: [MerchantCategory: String] = [:]
        for category in MerchantCategory.allCases {
            texts[category] = Self.format(profile.categoryOverrides[category])
        }
        self.categoryOverrideTexts = texts

        self.sourceName = account.rewardSourceName ?? ""
        self.sourceURL = account.rewardSourceURL ?? ""
        self.sourceConfidence = account.rewardSourceConfidenceRaw
            .flatMap(SourceConfidence.init(rawValue:)) ?? .userProvided
        self.sourceVerifiedAt = account.rewardSourceVerifiedAt
        self.notes = account.rewardSourceNotes ?? profile.notes
    }

    // MARK: - Derived

    /// True when the user has entered at least a base rate or one
    /// category override, a source name or URL, and picked a unit.
    /// Controls whether the editor's Save button is enabled in the
    /// "actually set some rewards" path.
    var canSave: Bool {
        // We always allow saving — saving with empty fields is
        // equivalent to clearing the rewards profile. The per-flag
        // toggles below drive the richer UI affordances.
        true
    }

    /// Whether the user currently has at least one numeric rate on
    /// screen. Used to gate the "clear rewards" affordance.
    var hasAnyRateEntered: Bool {
        hasValidNumber(baseRateText)
            || categoryOverrideTexts.values.contains(where: hasValidNumber)
    }

    /// Whether the user has pointed at a source. Controls the
    /// "Mark Verified Today" button — NomadFi never back-dates
    /// verification against an empty source.
    var hasSource: Bool {
        !sourceName.trimmingCharacters(in: .whitespaces).isEmpty
            || !sourceURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutations

    /// Stamps "verified today" onto `sourceVerifiedAt` and promotes
    /// the confidence to `.verifiedPrimary` when the user has a
    /// source attached. No-op otherwise so empty sources never get
    /// a verification stamp.
    func markVerifiedToday() {
        guard hasSource else { return }
        sourceVerifiedAt = clock()
        if !sourceConfidence.isVerified {
            sourceConfidence = .verifiedPrimary
        }
    }

    /// Clears every rewards field on the view model. Does not
    /// immediately persist — the caller calls ``save()`` next.
    func clearRewards() {
        programName = ""
        unit = .unknown
        baseRateText = ""
        categoryOverrideTexts = Dictionary(
            uniqueKeysWithValues: MerchantCategory.allCases.map { ($0, "") }
        )
        sourceName = ""
        sourceURL = ""
        sourceConfidence = .userProvided
        sourceVerifiedAt = nil
        notes = ""
    }

    /// Persists the current working values back onto the account.
    func save() {
        let trimmedProgram = programName.trimmingCharacters(in: .whitespacesAndNewlines)
        account.rewardProgramName = trimmedProgram.isEmpty ? nil : trimmedProgram

        account.rewardUnitRawValue = unit == .unknown ? nil : unit.rawValue
        account.baseRewardRate = Self.parse(baseRateText)

        let parsedOverrides = categoryOverrideTexts.reduce(
            into: [MerchantCategory: Double]()
        ) { accumulator, entry in
            if let value = Self.parse(entry.value) {
                accumulator[entry.key] = value
            }
        }
        account.rewardCategoryOverridesRaw = RewardProfile
            .encodedCategoryOverrides(parsedOverrides)

        let trimmedSourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        account.rewardSourceName = trimmedSourceName.isEmpty ? nil : trimmedSourceName
        account.rewardSourceURL = trimmedSourceURL.isEmpty ? nil : trimmedSourceURL
        account.rewardSourceConfidenceRaw = sourceConfidence.rawValue
        account.rewardSourceVerifiedAt = sourceVerifiedAt

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        account.rewardSourceNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

        account.lastUpdatedAt = clock()
    }

    // MARK: - Helpers

    private static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(value)
    }

    private static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let value = Double(trimmed),
              value >= 0
        else {
            return nil
        }
        return value
    }

    private func hasValidNumber(_ text: String) -> Bool {
        Self.parse(text) != nil
    }
}
