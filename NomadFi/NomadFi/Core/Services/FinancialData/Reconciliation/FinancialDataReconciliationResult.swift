// FinancialDataReconciliationResult.swift
// NomadFi
//
// Deterministic summary of a single reconciliation pass. Value-typed
// so tests can assert every branch without touching SwiftData.
//
// The reconciler merges a ``FinancialDataSyncReport`` into the app's
// existing ``Account`` / ``Transaction`` store. Every snapshot lands
// in exactly one bucket below; callers render the numbers in the
// Financial Connections settings UI without rebuilding the underlying
// logic.

import Foundation

/// Summary of what changed on disk during one reconciliation pass.
struct FinancialDataReconciliationResult: Sendable, Equatable {

    /// Account snapshots that lined up with an existing ``Account``
    /// via durable provider identity — no new row inserted, no
    /// heuristic match used.
    var matchedAccountsByDurableLink: Int = 0

    /// Account snapshots that lined up with exactly one existing
    /// ``Account`` via the narrow fallback match (institution name +
    /// currency + account type). The reconciler refuses to pick
    /// when more than one account could match, so this number only
    /// counts unambiguous fallbacks.
    var matchedAccountsByFallback: Int = 0

    /// Account snapshots that produced a new ``Account`` row because
    /// no durable link and no unambiguous fallback existed.
    var createdAccounts: Int = 0

    /// Existing accounts that had their snapshot fields refreshed
    /// (balance, credit limit, available credit, statement balance)
    /// plus provider-link metadata.
    var updatedAccounts: Int = 0

    /// Transaction snapshots that produced a new ``Transaction`` row.
    var insertedTransactions: Int = 0

    /// Transaction snapshots that the deduper flagged as duplicates
    /// of a row already on the linked account. Reuses
    /// ``TransactionImportDeduper`` so the same rules that gate CSV
    /// imports gate provider reconciliation.
    var skippedDuplicateTransactions: Int = 0

    /// Snapshots (account or transaction) that the reconciler
    /// refused to act on because they matched more than one
    /// plausible row. Surfacing these prevents silent cross-account
    /// merges; the user can resolve the ambiguity manually.
    var unresolvedAmbiguousSnapshots: Int = 0

    /// True when the pass neither created, updated, nor inserted
    /// anything. UI uses this to render a calm "no changes" summary.
    var isNoOp: Bool {
        matchedAccountsByDurableLink == 0
            && matchedAccountsByFallback == 0
            && createdAccounts == 0
            && updatedAccounts == 0
            && insertedTransactions == 0
            && skippedDuplicateTransactions == 0
            && unresolvedAmbiguousSnapshots == 0
    }

    static let empty = FinancialDataReconciliationResult()
}
