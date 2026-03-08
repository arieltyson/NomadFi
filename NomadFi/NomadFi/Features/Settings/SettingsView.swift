// SettingsView.swift
// NomadFi
//
// Main settings screen providing jurisdiction management,
// notification preferences, privacy controls, and app information.

import LocalAuthentication
import SwiftData
import SwiftUI

/// The app's settings screen organized into clear sections.
///
/// Provides controls for:
/// - Jurisdiction and currency management
/// - Notification preferences
/// - Privacy and data management
/// - Accessibility information
/// - About and legal links
struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]
    @Query private var subscriptions: [Subscription]

    @State private var notificationManager = NotificationManager()
    @State private var appLockManager = AppLockManager()
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingPrivacyPolicy = false

    var body: some View {
        List {
            jurisdictionsSection

            securitySection

            notificationsSection

            privacySection

            accessibilitySection

            aboutSection
        }
        .navigationTitle("Settings")
        .glassToolbar()
        .confirmationDialog(
            "Delete All Data",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                DataGovernancePolicy.deleteAllUserData(
                    in: modelContext,
                    notificationManager: notificationManager
                )
            }
        } message: {
            Text("This permanently removes all accounts, transactions, receipts, subscriptions, and budgets from this device. This cannot be undone.")
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            PrivacyPolicySheet()
        }
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Sections

private extension SettingsView {

    // MARK: Security

    var securitySection: some View {
        Section {
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

    // MARK: Jurisdictions

    var jurisdictionsSection: some View {
        Section {
            ForEach(jurisdictions) { jurisdiction in
                JurisdictionSettingsRow(jurisdiction: jurisdiction)
            }
        } header: {
            Text("Your Jurisdictions")
        } footer: {
            Text("Manage the countries where your money lives. To add or remove jurisdictions, re-run onboarding.")
        }
        .accessibilityLabel("Jurisdictions section")
    }

    // MARK: Notifications

    var notificationsSection: some View {
        Section {
            if notificationManager.isAuthorized {
                NotificationToggle(
                    title: "Subscription Reminders",
                    subtitle: "3 days before renewal",
                    systemImage: "bell.badge",
                    isEnabled: true
                )

                NotificationToggle(
                    title: "Budget Alerts",
                    subtitle: "At 80%, 90%, and 100%",
                    systemImage: "chart.bar",
                    isEnabled: true
                )

                NotificationToggle(
                    title: "FX Rate Alerts",
                    subtitle: "When rates move more than 2%",
                    systemImage: "arrow.triangle.swap",
                    isEnabled: true
                )

                NotificationToggle(
                    title: "Weekly Summary",
                    subtitle: "Every Saturday morning",
                    systemImage: "calendar.badge.clock",
                    isEnabled: true
                )
            } else {
                Button("Enable Notifications", systemImage: "bell") {
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }
                .accessibilityHint("Requests permission to send financial alerts and reminders")
            }
        } header: {
            Text("Notifications")
        } footer: {
            if !notificationManager.isAuthorized {
                Text("Enable notifications to receive subscription reminders, budget alerts, and FX rate movement warnings.")
            }
        }
    }

    // MARK: Privacy

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

    // MARK: Accessibility

    var accessibilitySection: some View {
        Section("Accessibility") {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("VoiceOver Optimized")
                        .font(TypographyTokens.body)
                    Text("Every screen narrates as a coherent financial story.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "accessibility")
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
            .accessibilityElement(children: .combine)

            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("Dynamic Type")
                        .font(TypographyTokens.body)
                    Text("All text scales to your preferred size, including the largest accessibility sizes.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "textformat.size")
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: About

    var aboutSection: some View {
        Section("About NomadFi") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(appVersion)")

            Label {
                Text("Built for International Students")
                    .font(TypographyTokens.body)
            } icon: {
                Image(systemName: "globe")
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
            .accessibilityLabel("NomadFi is built specifically for international students managing money across borders")
        }
    }
}

// MARK: - Helpers

private extension SettingsView {

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Jurisdiction Settings Row

/// Displays a jurisdiction with its flag, name, currency, and home indicator.
private struct JurisdictionSettingsRow: View {

    let jurisdiction: JurisdictionProfile

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(spacing: SpacingTokens.xSmall) {
                    Text(jurisdiction.countryName)
                        .font(TypographyTokens.body)

                    if jurisdiction.isHome {
                        Text("Home")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, SpacingTokens.xxSmall)
                            .padding(.vertical, 2)
                            .background(
                                ColorTokens.actionTint.opacity(increasedContrast ? 0.28 : 0.15)
                            )
                            .foregroundStyle(ColorTokens.actionTint)
                            .overlay {
                                if increasedContrast {
                                    Capsule()
                                        .strokeBorder(
                                            Color.primary.opacity(0.6),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .clipShape(.capsule)
                    }
                }

                if let currency = jurisdiction.currencyCode {
                    Text("\(currency.symbol) \(currency.displayName)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Text(String.flagEmoji(for: jurisdiction.countryCode))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var label = "\(jurisdiction.countryName)"
        if jurisdiction.isHome { label += ", home jurisdiction" }
        if let currency = jurisdiction.currencyCode {
            label += ", currency: \(currency.displayName)"
        }
        return label
    }
}

// MARK: - Notification Toggle

/// A toggle-style row for notification preferences.
private struct NotificationToggle: View {

    let title: String
    let subtitle: String
    let systemImage: String
    let isEnabled: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(title)
                    .font(TypographyTokens.body)

                Text(subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [
        JurisdictionProfile.self,
        Account.self,
        Transaction.self,
        Subscription.self,
        TaxDocument.self,
        Budget.self,
        ExchangeRate.self,
    ], inMemory: true)
}
