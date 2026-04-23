// FinancialTransactionSnapshot.swift
// NomadFi
//
// Provider-neutral snapshot of a single transaction returned by a
// ``FinancialDataProvider``. Kept intentionally thin — the full
// domain ``Transaction`` model carries provenance, tax-suggestion
// state, dedupe fields, and FX breakdowns that upstream providers
// cannot fill in reliably. The coordinator merges snapshots onto
// ``Transaction`` rows, stamping provenance as it goes.

import Foundation

/// Provider-neutral snapshot of a single transaction. Consumed by the
/// ``FinancialDataSyncCoordinator`` when merging into SwiftData.
struct FinancialTransactionSnapshot: Sendable, Equatable, Identifiable {

    let id: String
    let providerKind: FinancialDataProviderKind

    /// Account ID this transaction belongs to, scoped to the same
    /// provider as `providerKind`.
    let accountID: String

    let merchantName: String
    let amount: Double
    let currencyCode: CurrencyCode
    let date: Date

    /// Best-effort category classification. Providers that cannot
    /// classify fall back to ``TransactionCategory/other``; the
    /// coordinator never invents a tax-relevant category from an
    /// upstream ambiguous row.
    let category: TransactionCategory

    /// Upstream identifier (FinanceKit transaction UUID, CSV row
    /// fingerprint, aggregator transaction ID). Fed to
    /// ``TransactionImportDeduper`` so imports from different
    /// providers don't double-book the same row.
    let externalTransactionID: String?

    init(
        id: String,
        providerKind: FinancialDataProviderKind,
        accountID: String,
        merchantName: String,
        amount: Double,
        currencyCode: CurrencyCode,
        date: Date,
        category: TransactionCategory = .other,
        externalTransactionID: String? = nil
    ) {
        self.id = id
        self.providerKind = providerKind
        self.accountID = accountID
        self.merchantName = merchantName
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.category = category
        self.externalTransactionID = externalTransactionID
    }
}
