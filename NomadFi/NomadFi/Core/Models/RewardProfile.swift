// RewardProfile.swift
// NomadFi
//
// Pure value projection of the user-entered reward terms on a
// credit-card `Account`. Stays SwiftData- and SwiftUI-free so the
// engine, settings view model, and tests can work with it without
// opening a `ModelContainer`.

import Foundation

/// User-recorded reward terms for a single credit-card account.
///
/// Every field is optional. A profile is only *usable* when the user
/// has supplied a base rate or a category override and pointed at an
/// official source. The engine consumes a ``RewardRateEvaluation``
/// derived from this profile, not the profile directly.
struct RewardProfile: Sendable, Equatable {

    /// Short, user-visible name of the rewards program — e.g.
    /// "Amex Cobalt", "Chase Freedom Rise". Never guessed.
    var programName: String

    /// Unit the rates are denominated in. Defaults to ``RewardUnit/unknown``
    /// which the engine treats as "no reward signal".
    var unit: RewardUnit

    /// Base earn rate applied when no category override exists for
    /// the purchase category. `nil` means the user hasn't entered a
    /// base rate — the engine treats it as "no signal".
    var baseRate: Double?

    /// Category-specific overrides keyed by ``MerchantCategory``.
    /// Only rates are overridden — the unit is program-wide.
    var categoryOverrides: [MerchantCategory: Double]

    /// Provenance for the reward terms. Reuses ``SourceProvenance``
    /// so the freshness / confidence machinery already shipped for
    /// FX fees carries over unchanged.
    var provenance: SourceProvenance

    /// Free-form notes the user entered alongside the source. Shown
    /// in the editor, never spoken.
    var notes: String

    // MARK: - Init

    init(
        programName: String = "",
        unit: RewardUnit = .unknown,
        baseRate: Double? = nil,
        categoryOverrides: [MerchantCategory: Double] = [:],
        provenance: SourceProvenance = RewardProfile.unverifiedUserEntered,
        notes: String = ""
    ) {
        self.programName = programName
        self.unit = unit
        self.baseRate = baseRate
        self.categoryOverrides = categoryOverrides
        self.provenance = provenance
        self.notes = notes
    }

    // MARK: - Derived

    /// True when the user has recorded at least one numeric rate
    /// (base or category override). Controls whether the engine
    /// bothers to evaluate rewards at all.
    var hasAnyRate: Bool {
        baseRate != nil || !categoryOverrides.isEmpty
    }

    /// Effective rate for `category` — category override first,
    /// then base rate, then `nil` when neither is known.
    func rate(for category: MerchantCategory) -> Double? {
        if let override = categoryOverrides[category] {
            return override
        }
        return baseRate
    }

    // MARK: - Stock provenance

    /// Provenance used when the user enters reward numbers but has
    /// not yet pointed at an official source. Mirrors
    /// ``SourceProvenance/userEnteredAccountFee`` so unverified
    /// rewards are treated identically to unverified FX fees.
    static let unverifiedUserEntered: SourceProvenance = SourceProvenance(
        name: "User-entered rewards",
        urlString: nil,
        type: .userEntered,
        confidence: .userProvided,
        jurisdiction: .unknown,
        accessedAt: nil,
        notes: "Rate entered manually; not verified against issuer disclosure."
    )
}

// MARK: - Codable for category overrides

extension RewardProfile {

    /// Serialises ``categoryOverrides`` to a CloudKit-safe String.
    /// Keys are the stable `MerchantCategory.rawValue`s so a future
    /// category addition is forward-compatible — unknown keys at
    /// decode time are simply dropped.
    static func encodedCategoryOverrides(
        _ overrides: [MerchantCategory: Double]
    ) -> String? {
        guard !overrides.isEmpty else { return nil }
        let stringKeyed = Dictionary(
            uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) }
        )
        guard let data = try? JSONEncoder().encode(stringKeyed),
              let raw = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return raw
    }

    /// Decodes a previously encoded overrides string. Malformed or
    /// nil input → empty dictionary; never crashes.
    static func decodedCategoryOverrides(
        _ raw: String?
    ) -> [MerchantCategory: Double] {
        guard let raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let stringKeyed = try? JSONDecoder().decode(
                [String: Double].self,
                from: data
              )
        else {
            return [:]
        }

        var result: [MerchantCategory: Double] = [:]
        for (key, value) in stringKeyed {
            guard let category = MerchantCategory(rawValue: key) else {
                continue
            }
            result[category] = value
        }
        return result
    }
}
