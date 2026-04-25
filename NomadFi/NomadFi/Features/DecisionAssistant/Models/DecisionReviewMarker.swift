// DecisionReviewMarker.swift
// NomadFi
//
// Minimal CloudKit-safe persistence marker that records when the
// user has explicitly opened a Decision Assistant brief whose
// engine has no other input footprint to anchor "previously
// reviewed" semantics on.
//
// Today this is used only for the Credit Timing brief: that
// engine reads the user's saved credit cards live, so there is
// no per-engine input record like Scenario 1's
// `ScenarioDecisionRecord` or the Purchase Card Check's
// `PurchaseDecisionRecord`. Without this marker, "Previous
// decisions" would have to fall back to the weak heuristic
// "any credit card on file" (which is true *before* the user
// has ever opened the engine).
//
// Scenario 1 and the Purchase Card Check do not use this marker
// — their per-engine records already carry stronger input
// evidence. See `DecisionReviewEvidence` for the unified rule.
//
// CloudKit-safe by construction:
//   - No `@Attribute(.unique)` (CloudKit-synced stores reject
//     unique attributes). Application-level uniqueness is
//     enforced by `fetchOrCreate(for:in:)`.
//   - Every property has a default or is optional.
//   - No relationships — the marker is self-contained so future
//     migrations don't have to walk a graph.

import Foundation
import OSLog
import SwiftData

/// On-device marker that records the last time the user opened a
/// Decision Assistant brief whose engine has no other input
/// footprint. One row per `DecisionID`. Application code
/// (`fetchOrCreate(for:in:)`) keeps that uniqueness — the schema
/// stays CloudKit-friendly.
@Model
final class DecisionReviewMarker {

    /// `DecisionID.rawValue`. Stored as a String so the SwiftData
    /// schema stays stable when new decision identities are added
    /// to the catalog.
    var decisionIDRawValue: String = ""

    /// Timestamp of the most recent explicit review event. `nil`
    /// for a freshly-inserted row that has not been stamped yet.
    var lastReviewedAt: Date? = nil

    init(
        decisionIDRawValue: String = "",
        lastReviewedAt: Date? = nil
    ) {
        self.decisionIDRawValue = decisionIDRawValue
        self.lastReviewedAt = lastReviewedAt
    }

    // MARK: - Typed projection

    /// Typed `DecisionID` view over `decisionIDRawValue`. Returns
    /// `nil` for raw values the catalog no longer recognises so a
    /// future enum change never crashes the UI.
    var decisionID: DecisionID? {
        DecisionID(rawValue: decisionIDRawValue)
    }
}

// MARK: - Bootstrap

extension DecisionReviewMarker {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionReviewMarker"
    )

    /// Returns the marker for `id`, inserting and saving a fresh
    /// (un-stamped) row if none exists. Application-level
    /// uniqueness anchor used in lieu of `@Attribute(.unique)`.
    @MainActor
    static func fetchOrCreate(
        for id: DecisionID,
        in modelContext: ModelContext
    ) -> DecisionReviewMarker {
        let raw = id.rawValue
        var descriptor = FetchDescriptor<DecisionReviewMarker>(
            predicate: #Predicate { $0.decisionIDRawValue == raw }
        )
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let fresh = DecisionReviewMarker(
            decisionIDRawValue: raw,
            lastReviewedAt: nil
        )
        modelContext.insert(fresh)
        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Failed to insert DecisionReviewMarker for \(raw, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return fresh
    }

    /// Stamps the marker for `id` with `now`. Pure helper used by
    /// the Decision Assistant view model when the user explicitly
    /// opens a brief.
    @MainActor
    static func stamp(
        _ id: DecisionID,
        in modelContext: ModelContext,
        now: Date = .now
    ) {
        let marker = fetchOrCreate(for: id, in: modelContext)
        marker.lastReviewedAt = now
        do {
            try modelContext.save()
        } catch {
            logger.error(
                "Failed to stamp DecisionReviewMarker for \(id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
