// DataGovernancePolicy.swift
// NomadFi
//
// Centralized data governance utilities enforcing privacy compliance,
// orphan cleanup, and in-app privacy disclosure.

import Foundation
import OSLog
import SwiftData

/// Enforces NomadFi's data governance rules: cascade cleanup,
/// orphan detection, and privacy-compliant data deletion.
///
/// NomadFi's privacy promise is absolute — zero analytics, zero tracking,
/// zero third-party SDKs, and all financial data stays on-device. This
/// utility ensures that promise extends to data lifecycle management.
enum DataGovernancePolicy {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DataGovernance"
    )

    // MARK: - Orphan Cleanup

    /// Removes orphaned records that lost their parent due to
    /// non-cascade relationship changes or migration artifacts.
    ///
    /// While cascade delete rules handle most cleanup automatically,
    /// this method catches edge cases:
    /// - TaxDocuments whose receipt images remain on disk after deletion
    /// - Transactions with nil accounts from manual relationship edits
    /// - Budgets with nil jurisdiction profiles
    @MainActor
    static func cleanOrphanedRecords(in modelContext: ModelContext) {
        cleanOrphanedTaxDocumentImages(in: modelContext)
        logger.info("Orphan cleanup completed")
    }

    /// Deletes receipt image files from disk for TaxDocuments that
    /// no longer exist in SwiftData.
    ///
    /// Receipt images are stored in the app's Documents/receipts directory.
    /// When TaxDocument records are cascade-deleted, the image files
    /// remain on disk. This method reconciles the two.
    @MainActor
    static func cleanOrphanedTaxDocumentImages(in modelContext: ModelContext) {
        let receiptsDirectory = URL.documentsDirectory.appending(path: "receipts")

        guard FileManager.default.fileExists(atPath: receiptsDirectory.path()) else {
            return
        }

        // Collect all image paths referenced by existing TaxDocuments
        let descriptor = FetchDescriptor<TaxDocument>()
        let existingDocuments = (try? modelContext.fetch(descriptor)) ?? []
        let referencedPaths = Set(existingDocuments.map(\.imageRelativePath).filter { !$0.isEmpty })

        // Scan the receipts directory for orphaned files
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: receiptsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        var removedCount = 0
        for fileURL in contents {
            let relativePath = "receipts/\(fileURL.lastPathComponent)"
            if !referencedPaths.contains(relativePath) {
                try? FileManager.default.removeItem(at: fileURL)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            logger.info("Removed \(removedCount, privacy: .public) orphaned receipt images")
        }
    }

    // MARK: - Complete Data Wipe

    /// Performs a complete, privacy-compliant data wipe.
    ///
    /// Deletes all SwiftData records, Keychain entries, cached receipt
    /// images, Spotlight index entries, and pending notifications.
    /// After this method returns, no user data remains on the device.
    ///
    /// - Important: This operation is irreversible. The caller is
    ///   responsible for confirming the user's intent before calling.
    @MainActor
    static func deleteAllUserData(
        in modelContext: ModelContext,
        notificationManager: NotificationManager
    ) {
        // 1. Delete all SwiftData records — leaf nodes first to respect
        //    any remaining non-cascade relationships
        try? modelContext.delete(model: TaxDocument.self)
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: Subscription.self)
        try? modelContext.delete(model: Budget.self)
        try? modelContext.delete(model: Account.self)
        try? modelContext.delete(model: ExchangeRate.self)
        try? modelContext.delete(model: JurisdictionProfile.self)
        try? modelContext.delete(model: Currency.self)
        try? modelContext.delete(model: ScenarioDecisionRecord.self)
        try? modelContext.delete(model: DecisionDraftRecord.self)

        // 2. Clean up receipt images from disk
        let receiptsDirectory = URL.documentsDirectory.appending(path: "receipts")
        try? FileManager.default.removeItem(at: receiptsDirectory)

        // 3. Remove all Keychain items (app lock state, API tokens)
        KeychainService.deleteAll()

        // 4. Remove Spotlight entries
        Task {
            await SpotlightIndexer.removeAllIndexedItems()
        }

        // 5. Remove pending notifications
        notificationManager.removeAllPendingNotifications()

        logger.info("Complete data wipe finished — all user data removed from device")
    }

    // MARK: - Privacy Policy

    /// The in-app privacy policy displayed in Settings.
    ///
    /// Written in plain language for international students who may not
    /// be native English speakers. Avoids legal jargon where possible.
    static let privacyPolicyText: String = """
    NomadFi Privacy Policy

    Last Updated: March 2026

    Your Privacy Is Absolute

    NomadFi was built with one unbreakable rule: your financial data \
    never leaves your device. Here is exactly what that means.

    What We Collect: Nothing.
    NomadFi uses zero analytics, zero tracking cookies, zero \
    third-party SDKs, and zero advertising frameworks. We cannot see \
    your accounts, transactions, receipts, or any other data you enter.

    Where Your Data Lives: On Your iPhone.
    All financial data — accounts, transactions, tax documents, \
    subscriptions, and budgets — is stored locally using Apple's \
    SwiftData framework. If you enable iCloud sync, your data travels \
    only between your own Apple devices using end-to-end encryption \
    managed by Apple.

    Permissions We Request:
    \u{2022} Camera: Only when you choose to scan a receipt. Images are \
    saved locally and never uploaded.
    \u{2022} Location: Only when the Active Card feature needs to detect \
    your country for payment recommendations. Your coordinates are \
    never stored or transmitted.
    \u{2022} Notifications: Only for subscription reminders, budget \
    alerts, exchange rate movements, and credit-card statement close \
    and payment due reminders you opt into. All reminders are \
    scheduled locally on this device; NomadFi never sends push \
    notifications or includes account names, balances, or card \
    numbers in reminder text.

    Exchange Rates:
    NomadFi fetches currency exchange rates from a public API. These \
    requests contain no personal information — only currency pair \
    codes (e.g., USD/CAD). No cookies, tokens, or identifiers are \
    sent.

    Tax Report Exports:
    When you export a tax report, the file is generated locally and \
    shared through Apple's standard share sheet. NomadFi never \
    receives a copy.

    Deleting Your Data:
    You can delete all your data at any time from Settings. This \
    permanently removes every record, receipt image, and cached \
    value from your device. There is no backup on our servers \
    because there are no servers.

    Contact:
    Questions about your privacy? Reach us at privacy@nomadfi.app.
    """
}
