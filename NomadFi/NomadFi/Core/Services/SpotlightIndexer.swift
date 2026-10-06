// SpotlightIndexer.swift
// NomadFi
//
// Indexes accounts and subscriptions for Spotlight search.
// Enables users to find their financial data via system search.

import CoreSpotlight
import Foundation
import OSLog

/// Manages Spotlight search indexing for NomadFi's financial data.
///
/// Indexes accounts and subscriptions as `CSSearchableItem` entries,
/// enabling users to find their financial information from the system
/// Spotlight search and get deep links back into the app.
///
/// - Note: All methods are `@MainActor` because they access SwiftData
///   `@Model` objects which are main-actor isolated.
enum SpotlightIndexer {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Spotlight")

    /// The domain identifier for NomadFi's Spotlight entries.
    private static let domainIdentifier = "com.nomadfi.app"

    // MARK: - Account Indexing

    /// Indexes all accounts for Spotlight search.
    ///
    /// Each account becomes searchable by name, institution, and jurisdiction.
    @MainActor
    static func indexAccounts(_ accounts: [Account]) async {
        let items = accounts.map { account in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = account.name
            attributes.contentDescription = "\(account.institutionName) • \(account.currencyCode?.displayName ?? "Unknown currency")"
            attributes.keywords = [
                account.name,
                account.institutionName,
                account.jurisdiction,
                account.currencyCode?.displayName ?? "",
            ]

            return CSSearchableItem(
                uniqueIdentifier: "account-\(account.name)-\(account.institutionName)",
                domainIdentifier: domainIdentifier,
                attributeSet: attributes
            )
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            logger.info("Indexed \(items.count) accounts for Spotlight")
        } catch {
            logger.error("Spotlight account indexing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription Indexing

    /// Indexes all subscriptions for Spotlight search.
    ///
    /// Each subscription becomes searchable by service name and jurisdiction.
    @MainActor
    static func indexSubscriptions(_ subscriptions: [Subscription]) async {
        let items = subscriptions.map { subscription in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = subscription.serviceName
            let currencyDisplay = subscription.currencyCode?.rawValue ?? "USD"
            let amount = subscription.amount.formatted(.money(code: currencyDisplay))
            let frequency = subscription.frequency?.displayName ?? "recurring"
            attributes.contentDescription = "\(amount) \(frequency)"
            attributes.keywords = [
                subscription.serviceName,
                subscription.jurisdiction,
                subscription.currencyCode?.displayName ?? "",
            ]

            return CSSearchableItem(
                uniqueIdentifier: "subscription-\(subscription.serviceName)",
                domainIdentifier: domainIdentifier,
                attributeSet: attributes
            )
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            logger.info("Indexed \(items.count) subscriptions for Spotlight")
        } catch {
            logger.error("Spotlight subscription indexing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Removes all NomadFi entries from the Spotlight index.
    static func removeAllIndexedItems() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
            logger.info("Removed all Spotlight entries")
        } catch {
            logger.error("Spotlight cleanup failed: \(error.localizedDescription)")
        }
    }
}
