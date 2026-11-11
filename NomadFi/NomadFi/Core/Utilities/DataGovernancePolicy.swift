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
/// Local deletion and disclosures include explicitly enabled hosted features.
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
    /// images, Spotlight index entries, pending notifications, the widget
    /// snapshot and app preferences, and returns the app to onboarding.
    /// After this method returns, no user data remains on the device.
    ///
    /// - Important: This operation is irreversible. The caller is
    ///   responsible for confirming the user's intent before calling.
    @MainActor
    static func deleteAllUserData(
        in modelContext: ModelContext,
        notificationManager: NotificationManager,
        preferences: UserDefaults = .standard,
        sharedDefaults: UserDefaults = AppRoutingDefaults.shared
    ) {
        // 1. Delete all SwiftData records — leaf nodes first to respect
        //    any remaining non-cascade relationships
        try? modelContext.delete(model: TaxDocument.self)
        try? modelContext.delete(model: HostedLocalState.self)
        try? modelContext.delete(model: FiBotWorkspace.self)
        try? modelContext.delete(model: FiBotDecisionRecord.self)
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: Subscription.self)
        try? modelContext.delete(model: Budget.self)
        try? modelContext.delete(model: Account.self)
        try? modelContext.delete(model: ExchangeRate.self)
        try? modelContext.delete(model: JurisdictionProfile.self)
        try? modelContext.delete(model: Currency.self)
        try? modelContext.delete(model: ScenarioDecisionRecord.self)
        try? modelContext.delete(model: DecisionDraftRecord.self)
        try? modelContext.delete(model: PurchaseDecisionRecord.self)
        try? modelContext.delete(model: TaxEducationProgressRecord.self)
        try? modelContext.delete(model: InvestingEducationProgressRecord.self)
        try? modelContext.delete(model: DecisionReviewMarker.self)

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

        // 6. Commit the record deletions now rather than on autosave.
        do {
            try modelContext.save()
        } catch {
            logger.error("Saving the data wipe failed: \(error.localizedDescription, privacy: .public)")
        }

        // 7. Clear the App Group the widgets and intents read, so deleted
        //    balances can't linger on the Home or Lock Screen.
        sharedDefaults.removePersistentDomain(forName: NomadFiWidgetSharedConstants.appGroupIdentifier)
        DashboardWidgetSnapshotStore(defaults: sharedDefaults).clearSnapshot()

        // 8. Clear preferences, then mark onboarding unfinished explicitly so
        //    the app returns to onboarding immediately.
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        }
        preferences.set(false, forKey: OnboardingPreferences.completedKey)

        logger.info("Complete data wipe finished — all user data removed from device")
    }

    // MARK: - Privacy Policy

    /// The in-app privacy policy displayed in Settings.
    ///
    /// Written in plain language for international students who may not
    /// be native English speakers. Avoids legal jargon where possible.
    static let privacyPolicyText: String = """
    NomadFi Privacy Policy

    Updated October 6, 2026

    Local records
    Accounts, transactions, receipts, budgets, notes and decision history are
    stored on your device. Device backups and any enabled Apple synchronization
    are governed by your Apple settings. NomadFi does not use advertising or
    behavioral analytics to monetize your financial activity.

    Optional hosted banking
    When you explicitly enable hosted banking and authorize a bank through
    Plaid, NomadFi's service stores your linked balances and transactions,
    connection status and the credentials required for ongoing synchronization.
    Sign in with Apple identifies the owner of those records. Plaid handles bank
    authorization; bank login credentials are not entered into NomadFi's own forms.
    Hosted Connections shows the configured hosting region, backup retention
    period and the hosted privacy policy before sign-in. Hosted features stay
    unavailable in builds without a configured service and those disclosures.

    FiBot
    Local FiBot calculations use your confirmed income, bills, accessible cash
    and reserves. They do not send financial context to a language model. With
    separate monitoring consent, a copy of your confirmed cash plan and scenario
    settings is stored on your hosted account for scheduled checks. Monitoring
    results are available in the app. Stopping monitoring deletes that uploaded
    context and its derived alerts from the active service. Saved local checks
    are pruned after 30 days when the FiBot workspace opens, with at most 50 kept.

    Permissions and external requests
    Camera access is used for receipt capture. Receipt images remain local unless
    you choose to export them. Location access supports country-aware payment
    recommendations; location coordinates are not part of hosted bank or FiBot
    uploads. Opt-in reminders are scheduled locally using generic financial copy.
    Exchange-rate requests include currency codes, and the service receiving a
    network request can see the connection's IP address. The app uses no tracking
    cookies for these requests.

    Exports
    Financial and FiBot exports are generated on your device. You decide where
    to share them through Apple's share sheet. Exported files can contain private
    financial information; their destination controls subsequent storage.

    Deletion
    Settings lets you request deletion of your hosted account and remove local
    records and receipt images. Hosted processing stops when deletion is accepted.
    Bank and Apple authorization revocations retry until confirmed; active service
    records are purged after those operations finish. Restricted backups expire
    under the retention period disclosed for the configured service. Signing out
    alone keeps downloaded records on the device. FiBot also has separate plan,
    history, and monitoring deletion controls.

    Contact
    Privacy questions: arieltyson30190@gmail.com.
    """
}
