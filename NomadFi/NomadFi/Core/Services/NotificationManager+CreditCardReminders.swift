// NotificationManager+CreditCardReminders.swift
// NomadFi
//
// Extension to the existing `NotificationManager` that turns planner
// output into real `UNNotificationRequest` instances and keeps pending
// credit-card reminders in sync with the user's confirmed schedules.
//
// Kept as an extension (not a new service) so there is exactly one
// owner of the notification centre — matching the app's existing
// single-service pattern for FX, subscriptions, and budgets.

import Foundation
import OSLog
import UserNotifications

/// Namespaced category identifier reused across every credit-card
/// reminder. Lets future iOS features (notification actions, grouped
/// summaries) attach to this category without touching identifiers.
private let creditCardReminderCategory = "CREDIT_CARD_REMINDER"

private let creditCardLogger = Logger(
    subsystem: "com.nomadfi.app",
    category: "CreditCardReminders"
)

extension NotificationManager {

    // MARK: - Public API

    /// Re-syncs pending credit-card reminders to match the supplied
    /// accounts. Existing credit-card-prefixed pending requests are
    /// cleared first, then eligible confirmed schedules get fresh
    /// one-shot requests.
    ///
    /// - Parameters:
    ///   - accounts: Every saved account. The method filters to
    ///     `.creditCard` types and ignores the rest.
    ///   - now: Injection point for the current moment. Tests can pin
    ///     this; production callers omit it.
    func scheduleCreditCardReminders(
        for accounts: [Account],
        now: Date = .now
    ) async {
        // Always clear first so stale reminders from renamed or
        // removed cards never outlive the sync.
        await removeAllCreditCardReminders()

        guard isAuthorized else {
            creditCardLogger.info("Authorization not granted — skipping credit-card reminder schedule")
            return
        }

        let creditCards = accounts.filter { $0.accountType == .creditCard }
        var scheduledCount = 0

        for account in creditCards {
            let schedule = CreditCardSchedule(account: account)
            let fingerprint = CreditCardReminderPlanner.fingerprint(
                accountName: account.name,
                institutionName: account.institutionName
            )
            let plans = CreditCardReminderPlanner.plans(
                for: schedule,
                accountFingerprint: fingerprint,
                now: now
            )
            for plan in plans {
                await submit(reminder: plan)
                scheduledCount += 1
            }
        }

        creditCardLogger.info(
            "Scheduled \(scheduledCount) credit-card reminder(s) across \(creditCards.count) credit-card account(s)"
        )
    }

    /// Removes every pending credit-card reminder. Other categories
    /// (subscriptions, budgets, FX, weekly summary) are untouched
    /// because removal is filtered by identifier prefix.
    func removeAllCreditCardReminders() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let matching = pending
            .filter {
                $0.identifier.hasPrefix(
                    CreditCardReminderPlanner.identifierPrefix
                )
            }
            .map(\.identifier)

        guard !matching.isEmpty else { return }

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: matching)
        creditCardLogger.info("Removed \(matching.count) pending credit-card reminder(s)")
    }

    // MARK: - Scheduling

    private func submit(reminder plan: CreditCardReminderPlan) async {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.categoryIdentifier = creditCardReminderCategory

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: plan.triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: plan.id,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            creditCardLogger.error(
                "Failed to schedule credit-card reminder: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
