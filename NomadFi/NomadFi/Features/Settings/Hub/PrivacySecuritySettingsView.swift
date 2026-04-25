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
    @Environment(AppLockManager.self) private var appLockManager

    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingDeleteConfirmation = false
    @State private var notificationManager = NotificationManager()

    var body: some View {
        List {
            securitySection
            privacySection
        }
        .navigationTitle("Privacy & Security")
        .glassToolbar()
        .destructiveDataLossAlert(
            "Delete All Data",
            isPresented: $isShowingDeleteConfirmation,
            confirmationLabel: "Delete Everything",
            message: "This permanently removes all accounts, transactions, receipts, subscriptions, and budgets from this device. This cannot be undone."
        ) {
            DataGovernancePolicy.deleteAllUserData(
                in: modelContext,
                notificationManager: notificationManager
            )
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            PrivacyPolicySheet()
        }
        .task {
            appLockManager.refreshBiometricAvailability()
        }
    }
}

// MARK: - Sections

private extension PrivacySecuritySettingsView {

    var securitySection: some View {
        @Bindable var appLockManager = appLockManager

        return Section {
            Toggle("App Lock", isOn: $appLockManager.isAppLockEnabled)
                .accessibilityHint(
                    appLockManager.isBiometricAvailable
                        ? "Requires \(appLockManager.biometricType == .faceID ? "Face ID" : "Touch ID") to open NomadFi"
                        : "Requires your device passcode to open NomadFi"
                )

            if appLockManager.isAppLockEnabled {
                Picker("Lock After", selection: $appLockManager.lockTimeout) {
                    ForEach(LockTimeout.allCases) { timeout in
                        Text(timeout.displayName).tag(timeout)
                    }
                }
                .accessibilityHint("Choose how long NomadFi waits before locking after you leave the app")
            }
        } header: {
            Text("Security")
        } footer: {
            if appLockManager.isBiometricAvailable {
                Text("When enabled, \(appLockManager.biometricType == .faceID ? "Face ID" : "Touch ID") is required to access your financial data.")
            } else {
                Text("When enabled, your device passcode is required to access your financial data.")
            }
        }
    }

    var privacySection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("On-Device Only")
                        .font(TypographyTokens.body)
                    Text("Your financial data never leaves your iPhone.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(ColorTokens.positive)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Privacy: all your financial data stays on your device")

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
        } footer: {
            Text("NomadFi uses zero analytics, zero tracking, and zero third-party SDKs.")
        }
    }
}
