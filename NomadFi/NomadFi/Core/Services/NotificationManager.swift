// NotificationManager.swift
// NomadFi
//
// Manages local notifications for financial alerts including
// FX rate movements, subscription renewals, budget warnings,
// and weekly spending summaries.

import Foundation
import OSLog
import UserNotifications

/// Manages NomadFi's local notification scheduling and authorization.
///
/// Provides a centralized API for scheduling financial alerts:
/// - FX rate significant movement (>2% daily change)
/// - Subscription renewal reminders (3 days before)
/// - Weekly spending summary (Saturday morning)
/// - Budget threshold warnings (80%, 90%, 100%)
///
/// Respects the user's notification preferences and Do Not Disturb settings.
///
/// - Note: `@MainActor` because it reads SwiftData `@Model` objects
///   when scheduling context-aware notifications.
@MainActor
@Observable
final class NotificationManager {

    // MARK: - State

    var isAuthorized = false
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Notifications")

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            Self.logger.info("Notification authorization \(granted ? "granted" : "denied")")
        } catch {
            Self.logger.error("Notification auth failed: \(error.localizedDescription)")
        }
    }

    /// Refreshes the current authorization status.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Subscription Renewal Reminders

    /// Schedules a reminder 3 days before a subscription renews.
    func scheduleRenewalReminder(for subscription: Subscription) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewal"

        let serviceName = subscription.serviceName
        let currency = subscription.currencyCode?.rawValue ?? "USD"
        let amount = subscription.amount.formatted(.currency(code: currency))
        content.body = "\(serviceName) renews in 3 days for \(amount). Open NomadFi to review."
        content.sound = .default
        content.categoryIdentifier = "SUBSCRIPTION_RENEWAL"

        let calendar = Calendar.current
        guard let triggerDate = calendar.date(byAdding: .day, value: -3, to: subscription.nextRenewalDate) else {
            return
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "renewal-\(serviceName)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Self.logger.info("Renewal reminder scheduled for \(serviceName)")
        } catch {
            Self.logger.error("Failed to schedule renewal: \(error.localizedDescription)")
        }
    }

    /// Schedules renewal reminders for all subscriptions.
    ///
    /// Removes stale reminders first, then batches new scheduling to
    /// minimize notification center round-trips. Only schedules reminders
    /// for subscriptions renewing within the next 30 days.
    func scheduleAllRenewalReminders(subscriptions: [Subscription]) async {
        // Remove all existing renewal reminders before re-scheduling
        let existingIDs = subscriptions.map { "renewal-\($0.serviceName)" }
        center.removePendingNotificationRequests(withIdentifiers: existingIDs)

        // Only schedule reminders for subscriptions renewing in the next 30 days
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        let upcoming = subscriptions.filter { $0.nextRenewalDate <= thirtyDaysFromNow }

        for subscription in upcoming {
            await scheduleRenewalReminder(for: subscription)
        }
        Self.logger.info("Scheduled \(upcoming.count) renewal reminders (of \(subscriptions.count) total)")
    }

    // MARK: - Budget Alerts

    /// Sends a budget threshold warning notification.
    ///
    /// Fires when spending reaches 80%, 90%, or 100% of the budget.
    func sendBudgetAlert(budget: Budget, threshold: BudgetThreshold) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.categoryIdentifier = "BUDGET_ALERT"
        content.sound = .default

        let budgetName = budget.name.isEmpty ? "weekly" : budget.name
        let currency = budget.currencyCode?.rawValue ?? "USD"
        let remaining = budget.remainingAmount.formatted(.currency(code: currency))

        switch threshold {
        case .approaching:
            content.body = "You've used 80% of your \(budgetName) budget. \(remaining) remaining."
        case .critical:
            content.body = "You've used 90% of your \(budgetName) budget. \(remaining) remaining."
        case .exceeded:
            content.body = "You've exceeded your \(budgetName) budget! Review your spending in NomadFi."
        }

        let request = UNNotificationRequest(
            identifier: "budget-\(budgetName)-\(threshold.rawValue)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Failed to schedule budget alert: \(error.localizedDescription)")
        }
    }

    // MARK: - FX Rate Alerts

    /// Sends an immediate notification for significant FX rate movement.
    ///
    /// - Parameters:
    ///   - baseCurrency: The base currency of the pair.
    ///   - targetCurrency: The target currency of the pair.
    ///   - changePercent: The percentage change (positive = strengthening).
    func sendFXRateAlert(
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        changePercent: Double
    ) async {
        guard isAuthorized, abs(changePercent) > 2.0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "FX Rate Movement"
        content.categoryIdentifier = "FX_ALERT"
        content.sound = .default

        let direction = changePercent > 0 ? "strengthened" : "weakened"
        let formatted = abs(changePercent).formatted(.number.precision(.fractionLength(1)))
        content.body = "\(baseCurrency.rawValue) has \(direction) \(formatted)% against \(targetCurrency.rawValue). Check NomadFi for details."

        let request = UNNotificationRequest(
            identifier: "fx-\(baseCurrency.rawValue)-\(targetCurrency.rawValue)-\(Date.now.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Failed to send FX alert: \(error.localizedDescription)")
        }
    }

    // MARK: - Weekly Summary

    /// Schedules a recurring weekly spending summary for Saturday morning.
    func scheduleWeeklySummary() async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Spending Summary"
        content.body = "Your weekly financial summary is ready. Open NomadFi to review your spending across all jurisdictions."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"

        // Saturday at 9:00 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 7  // Saturday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly-summary",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Self.logger.info("Weekly summary scheduled for Saturday mornings")
        } catch {
            Self.logger.error("Failed to schedule weekly summary: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Removes all pending notifications.
    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
        Self.logger.info("All pending notifications removed")
    }

    /// Removes notifications for a specific subscription.
    func removeRenewalReminder(for serviceName: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["renewal-\(serviceName)"])
    }
}

// MARK: - Budget Threshold

/// Budget spending thresholds that trigger notifications.
enum BudgetThreshold: String, Sendable {
    case approaching  // 80%
    case critical     // 90%
    case exceeded     // 100%+
}
