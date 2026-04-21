// CreditCardReminderPlan.swift
// NomadFi
//
// Value type describing a single local reminder the app intends to
// schedule for a credit-card statement calendar. The planner emits
// these; `NotificationManager` turns them into `UNNotificationRequest`
// objects. Keeping the shape pure lets tests pin eligibility, lead
// times, identifiers, and privacy-safe copy without touching the real
// notification centre.

import Foundation

/// The kind of credit-card reminder a plan represents.
enum CreditCardReminderKind: String, Sendable, Equatable, CaseIterable {

    /// Nudge a few days before the statement closes so the user can
    /// pay the balance down before the statement balance is typically
    /// reported to the credit bureaus. Issuer reporting can vary.
    case statementClose

    /// Nudge a few days before the payment due date so the user
    /// avoids interest, late fees, and payment-history damage.
    case paymentDue

    /// Namespaced identifier prefix used by both the planner and the
    /// scheduler so reminders can be removed by kind without touching
    /// unrelated notifications (FX, subscriptions, budgets, etc.).
    var identifierPrefix: String {
        switch self {
        case .statementClose: "credit-card-close-"
        case .paymentDue: "credit-card-due-"
        }
    }
}

/// A single scheduled reminder the planner has decided is worth
/// scheduling. Content is deliberately generic — no account names,
/// balances, or limits — so the Lock Screen never leaks financial
/// detail even when notifications are shown while locked.
struct CreditCardReminderPlan: Sendable, Equatable {

    /// Deterministic notification identifier. Always starts with the
    /// matching ``CreditCardReminderKind/identifierPrefix``.
    let id: String

    /// The reminder's kind — drives identifier prefix and copy.
    let kind: CreditCardReminderKind

    /// The wall-clock moment at which the notification should fire.
    let triggerDate: Date

    /// Lock-Screen-safe title. Generic by design.
    let title: String

    /// Lock-Screen-safe body. Generic by design; never contains
    /// account names, balances, card numbers, limits, or addresses.
    let body: String
}
