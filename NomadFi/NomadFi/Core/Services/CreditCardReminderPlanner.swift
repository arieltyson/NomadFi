// CreditCardReminderPlanner.swift
// NomadFi
//
// Pure eligibility + timing layer for credit-card reminders. Consumes a
// `CreditCardSchedule` (never the raw SwiftData model) so the planner
// stays deterministic and fully testable without importing UserNotifications.
//
// Policy rationale:
// • Statement close reminder: 2 days before close date at 09:00 local
//   time. Two days is usually enough lead to pay down a balance before
//   the statement cuts; 09:00 lands a notification at the start of the
//   user's day without over-nudging.
// • Payment due reminder: 3 days before due date at 09:00 local time.
//   Three days gives the user a weekend buffer in case the due date
//   lands on a Monday and the payment needs to clear.
// • One-shot only. Due dates often shift between cycles, so repeating
//   calendar triggers would silently drift. Each cycle's reminders are
//   scheduled from the user-confirmed schedule; the next cycle's
//   reminders land when the user updates the calendar in Settings.

import Foundation

/// Builds a privacy-safe list of reminder plans for a credit card's
/// confirmed statement calendar.
enum CreditCardReminderPlanner {

    // MARK: - Policy constants

    /// Days before `statementClosingDate` that the close reminder fires.
    static let statementCloseLeadDays: Int = 2

    /// Days before `paymentDueDate` that the payment reminder fires.
    static let paymentDueLeadDays: Int = 3

    /// Local hour at which every reminder is scheduled.
    static let reminderHour: Int = 9

    /// Shared prefix every credit-card reminder identifier starts with
    /// so batch cleanup can remove them without touching unrelated
    /// notifications (renewal, budget, FX).
    static let identifierPrefix: String = "credit-card-"

    // MARK: - Public API

    /// Planner entry point. Returns reminder plans for the supplied
    /// schedule when it's complete, in-order, and confirmed; returns
    /// an empty list otherwise. Trigger dates already in the past are
    /// dropped — iOS would not fire them and including them in tests
    /// would hide scheduling bugs.
    ///
    /// - Parameters:
    ///   - schedule: The user-confirmed card calendar. Must be
    ///     `state == .confirmed` for any plans to be emitted.
    ///   - accountFingerprint: Deterministic suffix appended to each
    ///     reminder identifier so multiple cards share the same
    ///     namespace without clashing. See
    ///     ``fingerprint(accountName:institutionName:)``.
    ///   - now: Injection point for the current moment. Lets tests
    ///     pin "now" and keeps the function deterministic.
    ///   - calendar: Calendar used for date math. Defaults to
    ///     `.current`; tests override to keep timezone behaviour stable.
    static func plans(
        for schedule: CreditCardSchedule,
        accountFingerprint: String,
        now: Date,
        calendar: Calendar = .current
    ) -> [CreditCardReminderPlan] {
        guard schedule.state == .confirmed else { return [] }

        var plans: [CreditCardReminderPlan] = []

        if let close = schedule.statementClosingDate,
           let trigger = triggerDate(
               from: close,
               leadDays: statementCloseLeadDays,
               hour: reminderHour,
               calendar: calendar
           ),
           trigger > now {
            plans.append(
                CreditCardReminderPlan(
                    id: "\(CreditCardReminderKind.statementClose.identifierPrefix)\(accountFingerprint)",
                    kind: .statementClose,
                    triggerDate: trigger,
                    title: "Statement Close Reminder",
                    body: "A credit card statement closes soon. Open NomadFi to review."
                )
            )
        }

        if let due = schedule.paymentDueDate,
           let trigger = triggerDate(
               from: due,
               leadDays: paymentDueLeadDays,
               hour: reminderHour,
               calendar: calendar
           ),
           trigger > now {
            plans.append(
                CreditCardReminderPlan(
                    id: "\(CreditCardReminderKind.paymentDue.identifierPrefix)\(accountFingerprint)",
                    kind: .paymentDue,
                    triggerDate: trigger,
                    title: "Credit Card Payment Due",
                    body: "A credit card payment is due soon. Open NomadFi to schedule a payment."
                )
            )
        }

        return plans
    }

    /// Deterministic per-account fingerprint appended to notification
    /// identifiers. Derived from institution + account name so:
    /// • two cards on the same institution with different names do
    ///   not collide;
    /// • the identifier stays stable across launches as long as the
    ///   user does not rename the account.
    ///
    /// Percent-encoding keeps the identifier URL-safe and readable in
    /// crash logs without leaking structured data (commas, pipes) the
    /// notification centre could misparse.
    static func fingerprint(
        accountName: String,
        institutionName: String
    ) -> String {
        let raw = "\(institutionName)|\(accountName)"
        return raw.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) ?? "unknown"
    }

    // MARK: - Internals

    private static func triggerDate(
        from base: Date,
        leadDays: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date? {
        guard let shifted = calendar.date(
            byAdding: .day,
            value: -leadDays,
            to: base
        ) else {
            return nil
        }
        return calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: shifted
        )
    }
}
