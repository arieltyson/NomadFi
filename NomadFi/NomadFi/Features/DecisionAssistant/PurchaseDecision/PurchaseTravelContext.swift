// PurchaseTravelContext.swift
// NomadFi
//
// Pure value type that captures whether a purchase is *likely*
// cross-border / travel-shaped, derived only from inputs the user
// has already supplied (no geolocation, no merchant-acceptance
// database, no live FX). The Phase 3 follow-through engine uses
// this to surface DCC / FX-verification / dispute-process caveats
// only when the context warrants them.
//
// Honesty contract:
//   • The flags below are *signals*, not certainties. NomadFi never
//     claims to know the merchant country.
//   • A `true` here only triggers procedural reminders and source
//     links — it does not change ranking on its own.
//   • Cross-currency status is computed against the candidate
//     accounts the engine sees, not against a guessed home currency.

import Foundation

/// Deterministic travel / cross-border signal pack for a single
/// purchase. Built by `from(context:accountCurrencies:)` so the
/// engine and the brief view share one source of truth.
struct PurchaseTravelContext: Sendable, Equatable, Hashable {

    /// `true` when the purchase currency differs from at least one
    /// candidate account currency — i.e. paying for this purchase
    /// from at least one of the user's accounts would cross
    /// currencies.
    let isCrossCurrency: Bool

    /// `true` when the user typed a non-empty location hint
    /// (city / region / country fragment). Never a precise
    /// geolocation.
    let hasLocationHint: Bool

    /// `true` when the user explicitly picked the `.travel` merchant
    /// category. Used as a soft tie-breaker — never assumed from
    /// merchant names.
    let isTravelCategory: Bool

    /// Convenience roll-up: any signal above. Drives whether the
    /// engine surfaces the cross-border guidance block.
    var isLikelyCrossBorder: Bool {
        isCrossCurrency || hasLocationHint || isTravelCategory
    }

    /// Empty travel signal — `false` everywhere. Used by the engine
    /// when there are no candidate accounts to compare against.
    static let none = PurchaseTravelContext(
        isCrossCurrency: false,
        hasLocationHint: false,
        isTravelCategory: false
    )

    // MARK: - Derivation

    /// Builds the travel context from a `PurchaseContext` plus the
    /// raw currency codes of the candidate accounts the engine is
    /// about to rank. Pure over its inputs.
    static func from(
        context: PurchaseContext,
        accountCurrencies: [String]
    ) -> PurchaseTravelContext {
        let purchaseCurrency = context.currencyCode.rawValue
        let normalisedAccounts = accountCurrencies
            .map { $0.uppercased() }
        let crossCurrency = !normalisedAccounts.isEmpty
            && normalisedAccounts.contains { $0 != purchaseCurrency }

        let trimmedHint = context.locationHint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasHint = !trimmedHint.isEmpty

        return PurchaseTravelContext(
            isCrossCurrency: crossCurrency,
            hasLocationHint: hasHint,
            isTravelCategory: context.category == .travel
        )
    }
}
