// DecisionDraftAccountSnapshot.swift
// NomadFi
//
// Pure projection of the user's `Account` rows the
// `DecisionDraftEvaluator` needs. Lets the evaluator stay free of
// SwiftData and stay deterministic over a tiny, value-typed input.

import Foundation

/// Minimal account snapshot the draft evaluator reasons about. The
/// detail view builds this from the live `@Query<Account>` and
/// passes it in.
struct DecisionDraftAccountSnapshot: Sendable, Equatable, Hashable {

    /// `true` when the user has at least one credit-card row on
    /// file. Drives whether a `creditTiming` draft can hand off to
    /// the existing Credit Timing brief.
    let hasAnyCreditCard: Bool

    /// Empty snapshot — used as a sensible default in tests and in
    /// the rare case the snapshot has not been built yet.
    static let empty = DecisionDraftAccountSnapshot(
        hasAnyCreditCard: false
    )
}
