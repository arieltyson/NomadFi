// FinancialAccountSnapshot.swift
// NomadFi
//
// Provider-neutral snapshot of an upstream account. Sits between each
// concrete provider and NomadFi's domain ``Account`` model so engines
// never import provider-specific types. The snapshot carries:
// - stable identity (external ID + provider kind)
// - typed account-shape fields (balances, credit info)
// - provenance (which provider produced it, when)
//
// Snapshots are *inputs* to the app's existing ``Account`` persistence
// — the coordinator hands them to a merge step; the snapshot itself
// never becomes a parallel authoritative model.

import Foundation

/// Provider-neutral snapshot of an account returned from a
/// ``FinancialDataProvider``. Intentionally thin: it carries enough
/// for the coordinator to reconcile with the SwiftData ``Account``
/// model and enough for UI to render honest provenance, but it does
/// not attempt to duplicate every field on the domain model.
struct FinancialAccountSnapshot: Sendable, Equatable, Identifiable {

    /// Stable identifier scoped to `providerKind`. For FinanceKit this
    /// is the on-device account UUID; for CSV imports this is a
    /// deterministic fingerprint; for manual entries this mirrors the
    /// ``Account`` model ID.
    let id: String

    /// Which provider produced the snapshot. The coordinator uses
    /// this to decide whether the value is fresh enough to feed into
    /// ``Account`` snapshot fields.
    let providerKind: FinancialDataProviderKind

    /// Optional, opaque institution identifier. Never rendered to the
    /// user directly — NomadFi prefers the issuer name the user
    /// already typed on ``Account``.
    let institutionIdentifier: String?

    /// Short display label, only used when the coordinator is asked
    /// to present a provider-level list (e.g. "pick an account to
    /// link"). Never promoted to the core ``Account`` row.
    let displayName: String

    /// Human-readable issuer label (e.g. "Chase", "CIBC"). Source is
    /// the provider; the app cross-checks against the ``Account``
    /// model rather than trusting it blindly.
    let institutionName: String

    /// Typed projection of the upstream account type. Providers that
    /// cannot classify an account fall back to `.checking` or surface
    /// the row as a degradation, never as a fake investment.
    let accountType: AccountType

    /// ISO currency code. Required — NomadFi cannot reason about
    /// cross-border balances when currency is unknown.
    let currencyCode: CurrencyCode

    /// Deposit-style balance. Nil means the provider could not
    /// return a live value (offline, permission scoping, pending
    /// aggregator sync). Never coerced to zero.
    let currentBalance: Double?

    /// Credit-limit capacity for credit cards. Nil for deposit /
    /// wallet accounts. Never counted as net worth.
    let creditLimit: Double?

    /// Remaining credit for credit cards. Nil means unknown; not a
    /// computed projection of `creditLimit - currentBalance` because
    /// issuers apply holds, pending transactions, and cycle windows
    /// that NomadFi cannot re-derive.
    let availableCredit: Double?

    /// Most recent statement balance from the upstream provider.
    let statementBalance: Double?

    /// When the provider last refreshed the upstream numbers. The
    /// coordinator uses this alongside ``FinancialSnapshotSource``'s
    /// freshness window to decide staleness.
    let refreshedAt: Date?

    init(
        id: String,
        providerKind: FinancialDataProviderKind,
        institutionIdentifier: String? = nil,
        displayName: String,
        institutionName: String,
        accountType: AccountType,
        currencyCode: CurrencyCode,
        currentBalance: Double? = nil,
        creditLimit: Double? = nil,
        availableCredit: Double? = nil,
        statementBalance: Double? = nil,
        refreshedAt: Date? = nil
    ) {
        self.id = id
        self.providerKind = providerKind
        self.institutionIdentifier = institutionIdentifier
        self.displayName = displayName
        self.institutionName = institutionName
        self.accountType = accountType
        self.currencyCode = currencyCode
        self.currentBalance = currentBalance
        self.creditLimit = creditLimit
        self.availableCredit = availableCredit
        self.statementBalance = statementBalance
        self.refreshedAt = refreshedAt
    }

    /// Snapshot-source label the coordinator should stamp onto the
    /// matching ``Account`` when reconciling. Keeps the existing
    /// ``FinancialSnapshotSource`` contract authoritative so engines
    /// and UI that already gate on it (freshness, trust) keep
    /// working unchanged.
    var persistedSnapshotSource: FinancialSnapshotSource {
        providerKind.persistedSnapshotSource
    }
}
