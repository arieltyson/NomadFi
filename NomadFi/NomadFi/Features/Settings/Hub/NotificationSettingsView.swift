// NotificationSettingsView.swift
// NomadFi
//
// Owns the notifications detail page — authorization prompt, the
// category summaries, and the credit-card reminder opt-in toggle
// with its live sync. Extracted so the Settings hub stays focused
// on navigation, not on managing notification state.

import SwiftData
import SwiftUI

struct NotificationSettingsView: View {

    @Query private var accounts: [Account]

    @State private var notificationManager = NotificationManager()

    @AppStorage("creditCardRemindersEnabled")
    private var creditCardRemindersEnabled: Bool = false

    var body: some View {
        List {
            notificationsSection
        }
        .navigationTitle("Notifications")
        .task {
            await notificationManager.refreshAuthorizationStatus()
            await syncCreditCardRemindersIfNeeded()
        }
    }
}

// MARK: - Sections

private extension NotificationSettingsView {

    var notificationsSection: some View {
        Section {
            if notificationManager.isAuthorized {
                NotificationReminderRow(
                    title: "Subscription Reminders",
                    subtitle: "3 days before renewal",
                    systemImage: "bell.badge"
                )

                NotificationReminderRow(
                    title: "Budget Alerts",
                    subtitle: "At 80%, 90%, and 100%",
                    systemImage: "chart.bar"
                )

                NotificationReminderRow(
                    title: "FX Rate Alerts",
                    subtitle: "When rates move more than 2%",
                    systemImage: "arrow.triangle.swap"
                )

                NotificationReminderRow(
                    title: "Weekly Summary",
                    subtitle: "Every Saturday morning",
                    systemImage: "calendar.badge.clock"
                )

                creditCardRemindersToggle
            } else {
                Button("Enable Notifications", systemImage: "bell") {
                    Task { await notificationManager.requestAuthorization() }
                }
                .accessibilityHint("Requests permission to send financial alerts and reminders")
            }
        } header: {
            Text("Reminders")
        } footer: {
            if notificationManager.isAuthorized {
                Text("Credit card reminders fire \(CreditCardReminderPlanner.statementCloseLeadDays) days before each confirmed statement close date and \(CreditCardReminderPlanner.paymentDueLeadDays) days before each confirmed payment due date. Paying before statement close can reduce reported utilization, but issuer reporting can vary.")
            } else {
                Text("Enable notifications to receive subscription reminders, budget alerts, FX rate movement warnings, and credit-card statement reminders.")
            }
        }
    }

    var creditCardRemindersToggle: some View {
        Toggle(isOn: $creditCardRemindersEnabled) {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("Credit Card Reminders")
                        .font(TypographyTokens.body)
                    Text("For confirmed statement close and payment due dates")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
        }
        .accessibilityHint(
            "Schedules reminders on your device \(CreditCardReminderPlanner.statementCloseLeadDays) days before each confirmed statement close date and \(CreditCardReminderPlanner.paymentDueLeadDays) days before each confirmed payment due date."
        )
        .onChange(of: creditCardRemindersEnabled) { _, newValue in
            handleCreditCardRemindersToggleChange(enabled: newValue)
        }
    }
}

// MARK: - Reminder Sync

private extension NotificationSettingsView {

    /// Handles the user flipping the Credit Card Reminders toggle —
    /// mirrors the original behaviour in `SettingsView`. If iOS denies
    /// permission the toggle flips itself back off so the UI never
    /// advertises a feature the system will silently suppress.
    func handleCreditCardRemindersToggleChange(enabled: Bool) {
        Task {
            if enabled {
                if !notificationManager.isAuthorized {
                    await notificationManager.requestAuthorization()
                }
                guard notificationManager.isAuthorized else {
                    creditCardRemindersEnabled = false
                    return
                }
                await notificationManager.scheduleCreditCardReminders(for: accounts)
            } else {
                await notificationManager.removeAllCreditCardReminders()
            }
        }
    }

    /// Re-syncs credit-card reminders on appear so a newly confirmed
    /// schedule, an updated date, or a deleted card is reflected in
    /// pending requests without the user toggling. The hub also runs
    /// this on Settings appear so it still syncs even when the user
    /// never opens this page.
    func syncCreditCardRemindersIfNeeded() async {
        guard creditCardRemindersEnabled else {
            await notificationManager.removeAllCreditCardReminders()
            return
        }
        guard notificationManager.isAuthorized else {
            creditCardRemindersEnabled = false
            await notificationManager.removeAllCreditCardReminders()
            return
        }
        await notificationManager.scheduleCreditCardReminders(for: accounts)
    }
}

// MARK: - Reminder Row

/// A read-only description of a system-scheduled reminder category.
/// These categories are not individually user-toggleable; this row
/// documents the cadence so the notifications page is honest about
/// when NomadFi will actually page the user.
private struct NotificationReminderRow: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

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
    }
}
