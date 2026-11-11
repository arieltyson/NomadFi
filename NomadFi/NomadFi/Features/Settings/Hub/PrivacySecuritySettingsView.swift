// PrivacySecuritySettingsView.swift
// NomadFi
//
// Owns the privacy & security detail page: App Lock, the privacy
// policy sheet, and the destructive "Delete All My Data" flow.
// Grouping these into one page keeps the two kinds of protection
// (prevent access vs. erase data) in a single place the user can
// reason about at once.
//
// The wipe-all-data flow is the most catastrophic action in the
// app — every account, transaction, receipt, subscription, budget,
// captured draft, and education-progress record is removed. It
// routes through the `destructiveDataLossAlert` design-system
// primitive (centered modal alert) rather than
// `.confirmationDialog` (anchored sheet/popover), per Apple HIG:
// alerts are the right control for destructive operations that
// risk irretrievable data loss.

import LocalAuthentication
import SwiftData
import SwiftUI

struct PrivacySecuritySettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.hostedBanking) private var hostedBanking

    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingDeleteConfirmation = false
    @State private var notificationManager = NotificationManager()
    @State private var deletionMessage: String?
    @State private var isDeleting = false

    var body: some View {
        List {
            privacySection
        }
        .navigationTitle("Privacy & Security")
        .destructiveDataLossAlert(
            "Delete All Data",
            isPresented: $isShowingDeleteConfirmation,
            confirmationLabel: "Delete Everything",
            message: "This permanently removes local accounts, transactions, receipts, subscriptions, and budgets. If hosted banking is enabled, bank access is stopped and hosted account deletion is requested first. This cannot be undone."
        ) {
            Task { await deleteData() }
        }
        .alert("Data deletion", isPresented: Binding(get: { deletionMessage != nil }, set: { if !$0 { deletionMessage = nil } })) {
            Button("OK", role: .cancel) { deletionMessage = nil }
        } message: { Text(deletionMessage ?? "") }
        .disabled(isDeleting)
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            PrivacyPolicySheet()
        }
    }
}

// MARK: - Sections

private extension PrivacySecuritySettingsView {

    func deleteData() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            let hostedStates = try modelContext.fetch(FetchDescriptor<HostedLocalState>())
            let hasHostedData = !hostedStates.isEmpty
            let fiBotConsent = try HostedFiBotConsent.load()
            let hasHostedFiBot = fiBotConsent != nil
            if hasHostedData || hasHostedFiBot || hostedBanking?.userID != nil {
                guard let hostedBanking, hostedBanking.userID != nil else {
                    deletionMessage = "Sign in to your hosted account before deleting all data. Your records have been kept."
                    return
                }
                guard let session = try await hostedBanking.client.session(),
                      hostedStates.allSatisfy({ $0.ownerID == session.tokens.userID.uuidString && $0.endpoint == session.endpoint.absoluteString }),
                      fiBotConsent == nil || (fiBotConsent?.userID == session.tokens.userID && fiBotConsent?.endpoint == session.endpoint) else {
                    deletionMessage = "Sign in to the account that owns this device's hosted data before deleting it. Your records have been kept."
                    return
                }
                try await hostedBanking.deleteHostedAccount()
            }
            DataGovernancePolicy.deleteAllUserData(in: modelContext, notificationManager: notificationManager)
        } catch {
            deletionMessage = "The hosted deletion request could not be confirmed. Your local records and sign-in are kept so you can retry."
        }
    }

    var privacySection: some View {
        Section {
            Button("Privacy Policy", systemImage: "doc.text") {
                isShowingPrivacyPolicy = true
            }
            .accessibilityHint("View how NomadFi protects your data")

            Button("Delete All My Data", systemImage: "trash", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
            .accessibilityHint("Permanently removes all accounts, transactions, receipts, and subscriptions from this device")
        } header: {
            Text("Privacy & Data")
        }
    }
}
