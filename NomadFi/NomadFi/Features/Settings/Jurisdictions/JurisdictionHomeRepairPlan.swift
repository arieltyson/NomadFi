// JurisdictionHomeRepairPlan.swift
// NomadFi
//
// Pure, Sendable repair planner for `JurisdictionProfile.isHome`.
// Splits the *decision* (which profile should be home) from the
// *application* (mutating SwiftData models + saving) so:
//
//   • SwiftUI surfaces can drive the repair from a `@Query` array
//     they already own — no synchronous `modelContext.fetch(...)`
//     from inside `.task { ... }`. That synchronous-fetch pattern
//     hit a SwiftData runtime trap on iOS 26 in `SettingsView` and
//     is the reason this helper exists.
//   • Non-SwiftUI callers (`JurisdictionManager`) can still ask for
//     a repair without duplicating the rule.
//   • The decision logic is unit-testable without spinning up a
//     `ModelContainer`.
//
// Apple HIG alignment:
//   • "Keep people in control" — the repair only fires when the
//     home set is *inconsistent* (zero homes with profiles present,
//     or duplicate homes after a CloudKit sync collision). It never
//     overrides a single, user-chosen home.
//   • Determinism — the winner is picked by `createdAt` ascending,
//     then `countryCode` lexicographic, so the same input always
//     yields the same output across replicas.

import Foundation

/// Pure planner that decides whether the user's `JurisdictionProfile`
/// home flag set needs to be collapsed onto a single deterministic
/// winner. Holds no `ModelContext` and never mutates anything — the
/// caller applies the plan.
enum JurisdictionHomeRepairPlan {

    /// What the caller should do after consulting the planner.
    enum Outcome: Sendable, Equatable {

        /// Nothing to do — either no profiles exist, or exactly one
        /// profile already carries `isHome == true`.
        case alreadyConsistent

        /// The set is inconsistent (zero or multiple homes). The
        /// caller should set `isHome = (profile === winner)` for
        /// every profile, then save once.
        case repair(winnerCountryCode: String)
    }

    /// Decides whether `profiles` need a home-flag repair, and if so
    /// which profile should win. Pure — does not touch SwiftData.
    ///
    /// - Parameter profiles: The currently persisted profiles, in any
    ///   order. The planner sorts internally so the result is stable.
    /// - Returns: `.alreadyConsistent` when the set is empty or has
    ///   exactly one home; `.repair(winnerCountryCode:)` otherwise.
    static func plan(
        for profiles: [JurisdictionProfile]
    ) -> Outcome {
        guard !profiles.isEmpty else { return .alreadyConsistent }

        let homes = profiles.filter(\.isHome)
        if homes.count == 1 { return .alreadyConsistent }

        // Deterministic winner: earliest `createdAt`, ties broken by
        // lexicographic `countryCode`. `displayOrder` is not used —
        // it is itself recalculated by `JurisdictionManager` after
        // add/remove, so it cannot be the source of truth here.
        let winner = profiles.min { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.countryCode < rhs.countryCode
            }
            return lhs.createdAt < rhs.createdAt
        }

        guard let winner else { return .alreadyConsistent }
        return .repair(winnerCountryCode: winner.countryCode)
    }
}
