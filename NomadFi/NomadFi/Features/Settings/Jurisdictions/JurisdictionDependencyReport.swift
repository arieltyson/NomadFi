// JurisdictionDependencyReport.swift
// NomadFi
//
// Pure, Sendable summary of how much user data is bound to a given
// jurisdiction code. The jurisdiction manager uses this to block
// removal when the user would otherwise silently orphan financial
// records, and to render a precise, factual explanation.

import Foundation

/// Count of records that reference a jurisdiction code across the
/// persistence layer. Every model that stores a free-text
/// `jurisdiction: String` is inspected — relying on the
/// `JurisdictionProfile.accounts` relationship alone is unsafe because
/// the string column can hold codes that were never wired back into a
/// profile relationship (legacy onboarding flow, imports, etc).
struct JurisdictionDependencyReport: Sendable, Equatable {

    let countryCode: String
    let accountCount: Int
    let budgetCount: Int
    let transactionCount: Int
    let subscriptionCount: Int
    let taxDocumentCount: Int

    /// True when at least one dependent record still references this
    /// jurisdiction — removal must be blocked.
    var hasDependents: Bool {
        accountCount + budgetCount + transactionCount + subscriptionCount + taxDocumentCount > 0
    }

    /// Human-readable list of the record types still in use, used by
    /// the management UI's "move or delete these first" footer. Empty
    /// when nothing references this jurisdiction.
    var blockingItems: [JurisdictionDependencyItem] {
        var items: [JurisdictionDependencyItem] = []
        if accountCount > 0 {
            items.append(JurisdictionDependencyItem(kind: .account, count: accountCount))
        }
        if transactionCount > 0 {
            items.append(JurisdictionDependencyItem(kind: .transaction, count: transactionCount))
        }
        if budgetCount > 0 {
            items.append(JurisdictionDependencyItem(kind: .budget, count: budgetCount))
        }
        if subscriptionCount > 0 {
            items.append(JurisdictionDependencyItem(kind: .subscription, count: subscriptionCount))
        }
        if taxDocumentCount > 0 {
            items.append(JurisdictionDependencyItem(kind: .taxDocument, count: taxDocumentCount))
        }
        return items
    }
}

/// Single row in ``JurisdictionDependencyReport/blockingItems``.
struct JurisdictionDependencyItem: Sendable, Equatable, Identifiable {

    enum Kind: String, Sendable {
        case account
        case transaction
        case budget
        case subscription
        case taxDocument
    }

    let kind: Kind
    let count: Int

    var id: String { kind.rawValue }

    /// Readable label like "3 accounts" or "1 subscription". Uses the
    /// `localizedStandardContains`-free path because the copy is not
    /// user-controlled.
    var displayText: String {
        let word: String
        switch kind {
        case .account: word = count == 1 ? "account" : "accounts"
        case .transaction: word = count == 1 ? "transaction" : "transactions"
        case .budget: word = count == 1 ? "budget" : "budgets"
        case .subscription: word = count == 1 ? "subscription" : "subscriptions"
        case .taxDocument: word = count == 1 ? "tax document" : "tax documents"
        }
        return "\(count) \(word)"
    }
}
