// JurisdictionManager.swift
// NomadFi
//
// Pure service that mutates the user's set of `JurisdictionProfile`
// records. The surface is intentionally narrow — add, remove, set home,
// inspect dependents, repair missing home — so the management UI stays
// a thin binding layer and the logic is testable without SwiftUI.

import Foundation
import OSLog
import SwiftData

/// Add / remove / re-home operations over `JurisdictionProfile`.
///
/// The manager is free-standing (not an `@Observable`) because the UI
/// reacts to `JurisdictionProfile` changes through `@Query`, not
/// through manager state. Every mutation re-computes `displayOrder`
/// deterministically so CloudKit sync never ends up with duplicate
/// ordinals.
@MainActor
struct JurisdictionManager {

    // MARK: - Errors

    enum JurisdictionOperationError: LocalizedError, Equatable {

        /// The country code maps to no entry in ``JurisdictionInfo/supported``.
        case unsupportedCountryCode(String)

        /// A profile with this country code already exists.
        case duplicateCountryCode(String)

        /// At least one dependent record still references this code.
        case hasDependents(JurisdictionDependencyReport)

        /// The profile to remove is currently the home jurisdiction.
        case cannotRemoveHome

        var errorDescription: String? {
            switch self {
            case let .unsupportedCountryCode(code):
                return "NomadFi does not have a built-in profile for \(code) yet."
            case let .duplicateCountryCode(code):
                return "A profile for \(code) already exists."
            case .hasDependents:
                return "This jurisdiction still has data attached to it."
            case .cannotRemoveHome:
                return "Set a different home jurisdiction before removing this one."
            }
        }
    }

    // MARK: - Dependencies

    private let modelContext: ModelContext

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "JurisdictionManager"
    )

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Queries

    /// All persisted profiles, sorted by `displayOrder`.
    func activeProfiles() throws -> [JurisdictionProfile] {
        let descriptor = FetchDescriptor<JurisdictionProfile>(
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Supported jurisdictions that are not yet active.
    func availableJurisdictions() throws -> [JurisdictionInfo] {
        let existing = Set(try activeProfiles().map(\.countryCode))
        return JurisdictionInfo.supported.filter { !existing.contains($0.id) }
    }

    /// Records still referencing a given country code across every
    /// model that stores a free-text `jurisdiction: String`. Counts
    /// live on the string column so imports and legacy rows that were
    /// never bound to a relationship still block removal.
    func dependencyReport(for countryCode: String) throws -> JurisdictionDependencyReport {
        let accounts = try modelContext.fetchCount(
            FetchDescriptor<Account>(
                predicate: #Predicate { $0.jurisdiction == countryCode }
            )
        )
        let budgets = try modelContext.fetchCount(
            FetchDescriptor<Budget>(
                predicate: #Predicate { $0.jurisdiction == countryCode }
            )
        )
        let transactions = try modelContext.fetchCount(
            FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.jurisdiction == countryCode }
            )
        )
        let subscriptions = try modelContext.fetchCount(
            FetchDescriptor<Subscription>(
                predicate: #Predicate { $0.jurisdiction == countryCode }
            )
        )
        let taxDocuments = try modelContext.fetchCount(
            FetchDescriptor<TaxDocument>(
                predicate: #Predicate { $0.jurisdiction == countryCode }
            )
        )
        return JurisdictionDependencyReport(
            countryCode: countryCode,
            accountCount: accounts,
            budgetCount: budgets,
            transactionCount: transactions,
            subscriptionCount: subscriptions,
            taxDocumentCount: taxDocuments
        )
    }

    // MARK: - Mutations

    /// Adds a supported jurisdiction as a new ``JurisdictionProfile``.
    /// No-op if the code already exists — the operation is idempotent
    /// on duplicates rather than throwing, since the user should not be
    /// blocked from re-tapping an "Add" row that just finished syncing.
    @discardableResult
    func addJurisdiction(with countryCode: String) throws -> JurisdictionProfile {
        guard let info = JurisdictionInfo.supported.first(where: { $0.id == countryCode }) else {
            throw JurisdictionOperationError.unsupportedCountryCode(countryCode)
        }

        let existing = try activeProfiles()
        if let duplicate = existing.first(where: { $0.countryCode == countryCode }) {
            return duplicate
        }

        let nextOrder = (existing.map(\.displayOrder).max() ?? -1) + 1
        let isHome = existing.isEmpty
        let profile = JurisdictionProfile(
            countryCode: info.id,
            countryName: info.name,
            currencyCode: info.currencyCode,
            isHome: isHome,
            displayOrder: nextOrder
        )
        modelContext.insert(profile)
        try modelContext.save()
        Self.logger.info("Added jurisdiction \(info.id, privacy: .public)")
        return profile
    }

    /// Removes a jurisdiction after verifying nothing still depends on
    /// it. The home jurisdiction can never be removed directly — the
    /// caller must re-home first. `displayOrder` is re-packed so the
    /// remaining profiles stay on a contiguous 0..<N sequence.
    func removeJurisdiction(_ profile: JurisdictionProfile) throws {
        if profile.isHome {
            throw JurisdictionOperationError.cannotRemoveHome
        }

        let report = try dependencyReport(for: profile.countryCode)
        guard !report.hasDependents else {
            throw JurisdictionOperationError.hasDependents(report)
        }

        modelContext.delete(profile)
        try modelContext.save()
        try recalculateDisplayOrder()
        Self.logger.info("Removed jurisdiction \(profile.countryCode, privacy: .public)")
    }

    /// Makes `profile` the sole home jurisdiction. Idempotent — calling
    /// with an already-home profile is a no-op.
    func setHomeJurisdiction(_ profile: JurisdictionProfile) throws {
        let profiles = try activeProfiles()
        for candidate in profiles {
            candidate.isHome = (candidate.persistentModelID == profile.persistentModelID)
        }
        try modelContext.save()
        Self.logger.info("Home jurisdiction set to \(profile.countryCode, privacy: .public)")
    }

    /// Ensures exactly one home profile exists when any profile does.
    /// If rows pre-dating this manager lost their home flag (multiple
    /// homes, or zero homes with profiles present), re-home to the
    /// deterministic winner picked by `JurisdictionHomeRepairPlan`
    /// so ordering is reproducible across CloudKit replicas.
    ///
    /// Non-SwiftUI callers use this method; SwiftUI views drive the
    /// same planner over their own `@Query` results to avoid the
    /// synchronous-fetch trap on iOS 26.
    @discardableResult
    func repairHomeJurisdictionIfNeeded() throws -> JurisdictionProfile? {
        let profiles = try activeProfiles()
        let outcome = JurisdictionHomeRepairPlan.plan(for: profiles)

        switch outcome {
        case .alreadyConsistent:
            return profiles.first(where: \.isHome)
        case let .repair(winnerCountryCode):
            var winner: JurisdictionProfile?
            for candidate in profiles {
                let shouldBeHome = candidate.countryCode == winnerCountryCode
                if candidate.isHome != shouldBeHome {
                    candidate.isHome = shouldBeHome
                }
                if shouldBeHome { winner = candidate }
            }
            try modelContext.save()
            if let winner {
                Self.logger.info("Repaired missing home to \(winner.countryCode, privacy: .public)")
            }
            return winner
        }
    }

    /// Re-packs `displayOrder` so it stays contiguous starting at zero
    /// after additions or removals. Sort order is preserved by reading
    /// the existing order first.
    func recalculateDisplayOrder() throws {
        let profiles = try activeProfiles()
        for (index, profile) in profiles.enumerated() where profile.displayOrder != index {
            profile.displayOrder = index
        }
        try modelContext.save()
    }
}
