// SettingsView.swift
// NomadFi
//
// Main settings screen providing jurisdiction management,
// notification preferences, privacy controls, and app information.

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

    var body: some View {
        List {
            jurisdictionsSection

            notificationsSection

            privacySection

            accessibilitySection

            aboutSection
        }
        .navigationTitle("Settings")
        .glassToolbar()
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }
}

// MARK: - Sections

private extension SettingsView {

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

            Button("Delete All My Data", systemImage: "trash", role: .destructive) {
                deleteAllData()
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

    func deleteAllData() {
        // Delete all SwiftData records
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: Account.self)
        try? modelContext.delete(model: Subscription.self)
        try? modelContext.delete(model: TaxDocument.self)
        try? modelContext.delete(model: Budget.self)
        try? modelContext.delete(model: ExchangeRate.self)

        // Clean up receipt images
        let receiptsDir = URL.documentsDirectory.appending(path: "receipts")
        try? FileManager.default.removeItem(at: receiptsDir)

        // Remove Spotlight entries
        Task {
            await SpotlightIndexer.removeAllIndexedItems()
        }

        // Remove pending notifications
        notificationManager.removeAllPendingNotifications()
    }
}

// MARK: - Jurisdiction Settings Row

/// Displays a jurisdiction with its flag, name, currency, and home indicator.
private struct JurisdictionSettingsRow: View {

    let jurisdiction: JurisdictionProfile

    var body: some View {
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
                            .background(ColorTokens.brandPrimary.opacity(0.15))
                            .foregroundStyle(ColorTokens.brandPrimary)
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
