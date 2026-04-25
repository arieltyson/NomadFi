// DecisionDraftListPresentation.swift
// NomadFi
//
// Pure value-layer adapter that decorates a draft list with its
// derived row readiness and groups the active rows so the most
// actionable drafts surface first. The Decision Assistant view
// renders the result; this helper does no IO and reads no
// `@Environment` value.
//
// Active-draft ordering (engine-ready first → requires-context →
// routed-to-advanced-tool → no-engine-yet, with `updatedAt`
// descending inside each group) is purely a presentation choice
// and never persists. Archived drafts keep their existing
// `updatedAt`-descending order on the archived surface — readiness
// is a no-op for them.

import Foundation

/// One drafted row paired with the readiness label the row should
/// render. Not `Sendable` — `DecisionDraftRecord` is a SwiftData
/// `@Model`, which is intentionally non-`Sendable`. The decorated
/// items are produced and consumed on the main actor (the view
/// owns the live records).
struct DecisionDraftListItem: Identifiable {

    /// Stable identifier for `ForEach` keying — uses the underlying
    /// `DecisionDraftRecord.draftID`.
    var id: UUID { draft.draftID }

    let draft: DecisionDraftRecord
    let readiness: DecisionDraftRowReadiness
}

enum DecisionDraftListPresentation {

    /// Decorates and group-sorts the active draft list so the most
    /// actionable rows surface first. Within each readiness group,
    /// rows stay sorted by `updatedAt` descending (matching the
    /// `@Query` order the view feeds in).
    ///
    /// - Parameter activeDrafts: Drafts the view's `@Query`
    ///   already filtered to `.needsEngine`. Order is assumed to
    ///   be `updatedAt` descending — this helper preserves that
    ///   relative order inside each readiness group rather than
    ///   re-sorting against `updatedAt` itself.
    static func decoratedActiveDrafts(
        _ activeDrafts: [DecisionDraftRecord],
        accountSnapshot: DecisionDraftAccountSnapshot
    ) -> [DecisionDraftListItem] {
        // Decorate first so each item already carries its readiness.
        let decorated = activeDrafts.map { draft in
            DecisionDraftListItem(
                draft: draft,
                readiness: DecisionDraftRowReadiness.from(
                    draft: draft,
                    accountSnapshot: accountSnapshot
                )
            )
        }

        // Sort by readiness group, breaking ties on `updatedAt`
        // descending. Swift's `sorted(by:)` is not documented as
        // stable, so the explicit secondary key keeps the order
        // inside each group deterministic.
        return decorated.sorted { lhs, rhs in
            if lhs.readiness.sortGroupRank != rhs.readiness.sortGroupRank {
                return lhs.readiness.sortGroupRank < rhs.readiness.sortGroupRank
            }
            return lhs.draft.updatedAt > rhs.draft.updatedAt
        }
    }

    /// Decorates the archived draft list. Archived rows do not
    /// reorder — readiness is always `.archived`, so the upstream
    /// `updatedAt`-descending order survives unchanged.
    static func decoratedArchivedDrafts(
        _ archivedDrafts: [DecisionDraftRecord]
    ) -> [DecisionDraftListItem] {
        archivedDrafts.map { draft in
            DecisionDraftListItem(
                draft: draft,
                readiness: .archived
            )
        }
    }
}
