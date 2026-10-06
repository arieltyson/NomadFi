// SettingsView.swift
// NomadFi
//
// The Settings tab's root: Notifications and Privacy & Security as
// rows, then a Financial Setup section of tiles — Accounts,
// Jurisdictions, Credit Card Calendar, Financial Connections — drawn
// like the Tools tab. Each pushes a page of its own, so nothing that
// grows with the person's data lengthens this screen.
//
// Side effects that must happen regardless of which sub-page the
// user opens (jurisdiction home repair, credit-card reminder re-sync)
// run on this root's `.task`, so they fire as soon as the tab is
// visited. Nothing on the root mutates account data directly.
//
// SwiftData reads use `@Query` rather than synchronous
// `modelContext.fetch(...)` calls. The synchronous-fetch pattern
// hit a SwiftData runtime trap on iOS 26 when invoked from inside
// `.task { ... }`; the canonical Apple-recommended approach is to
// declare the query and operate on its results. See
// `JurisdictionHomeRepairPlan` for the pure planner this view
// drives.

import OSLog
import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppLockManager.self) private var appLockManager

    @Query private var accounts: [Account]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictionProfiles: [JurisdictionProfile]

    @State private var notificationManager = NotificationManager()
    @State private var openSetupItem: FinancialSetupItem?

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "SettingsView"
    )

    @AppStorage("creditCardRemindersEnabled")
    private var creditCardRemindersEnabled: Bool = false

    var body: some View {
        List {
            Section {
                HubNavigationRow(
                    "Notifications",
                    systemImage: "bell.badge.fill",
                    tint: ColorTokens.warning,
                    value: notificationManager.isAuthorized ? "On" : "Off"
                ) {
                    NotificationSettingsView()
                }

                HubNavigationRow(
                    "Privacy & Security",
                    systemImage: "lock.shield.fill",
                    tint: ColorTokens.positive
                ) {
                    PrivacySecuritySettingsView()
                }
            }

            Section {
                TileGrid(items: FinancialSetupItem.allCases) { openSetupItem = $0 }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Financial Setup")
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(item: $openSetupItem) { item in
            FinancialSetupDestination(item: item)
        }
        .task {
            appLockManager.refreshBiometricAvailability()
            await notificationManager.refreshAuthorizationStatus()
            await syncCreditCardRemindersIfNeeded()
            repairHomeJurisdictionIfNeeded()
        }
    }
}

// MARK: - Root-level side effects

private extension SettingsView {

    /// Keeps pending credit-card reminders in sync with the user's
    /// current set of credit-card accounts and confirmed schedules,
    /// running regardless of whether the user opens the Notifications
    /// subpage. Mirrors the original behaviour from the pre-hub
    /// Settings.
    func syncCreditCardRemindersIfNeeded() async {
        guard creditCardRemindersEnabled else {
            await notificationManager.removeAllCreditCardReminders()
            return
        }
        guard notificationManager.isAuthorized else {
            // User revoked permission from iOS Settings — reflect that
            // state instead of leaving the toggle visually enabled.
            creditCardRemindersEnabled = false
            await notificationManager.removeAllCreditCardReminders()
            return
        }
        await notificationManager.scheduleCreditCardReminders(for: accounts)
    }

    /// Collapses duplicate-home or zero-home jurisdiction states on
    /// visit. Drives the pure `JurisdictionHomeRepairPlan` over the
    /// `@Query`-resolved profile set so SwiftData never sees a
    /// synchronous fetch from inside this view's `.task`. Cheap,
    /// no-op when the set is already consistent.
    func repairHomeJurisdictionIfNeeded() {
        let outcome = JurisdictionHomeRepairPlan.plan(for: jurisdictionProfiles)
        guard case let .repair(winnerCountryCode) = outcome else { return }

        for profile in jurisdictionProfiles {
            let shouldBeHome = profile.countryCode == winnerCountryCode
            if profile.isHome != shouldBeHome {
                profile.isHome = shouldBeHome
            }
        }

        do {
            try modelContext.save()
            Self.logger.info(
                "Repaired home jurisdiction to \(winnerCountryCode, privacy: .public)"
            )
        } catch {
            Self.logger.error(
                "Failed to save repaired home jurisdiction: \(error.localizedDescription, privacy: .public)"
            )
        }
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
