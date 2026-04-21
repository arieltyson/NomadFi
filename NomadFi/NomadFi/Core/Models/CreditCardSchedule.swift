// CreditCardSchedule.swift
// NomadFi
//
// Pure value projection of an `Account`'s credit-card statement
// calendar. Lives in Core/Models so both the Settings UI and the
// Scenario decision engine can consume it without cross-feature
// dependencies.

import Foundation

/// The three dates that describe a credit-card billing cycle, plus
/// the timestamp of the user's most recent confirmation.
///
/// Every property is optional — a nil value means "user has not
/// entered this yet", never zero. All helpers treat nils honestly
/// rather than assuming defaults.
struct CreditCardSchedule: Equatable, Sendable {

    /// First day of the current statement period.
    var statementPeriodStartDate: Date?

    /// Day the current statement closes and its balance is typically
    /// reported to the credit bureaus.
    var statementClosingDate: Date?

    /// Day the minimum payment is due for the current statement.
    var paymentDueDate: Date?

    /// Timestamp of the user's last confirmation of these dates.
    var lastConfirmedAt: Date?

    init(
        statementPeriodStartDate: Date? = nil,
        statementClosingDate: Date? = nil,
        paymentDueDate: Date? = nil,
        lastConfirmedAt: Date? = nil
    ) {
        self.statementPeriodStartDate = statementPeriodStartDate
        self.statementClosingDate = statementClosingDate
        self.paymentDueDate = paymentDueDate
        self.lastConfirmedAt = lastConfirmedAt
    }
}

// MARK: - Account bridge

extension CreditCardSchedule {

    /// Snapshots the schedule fields from an `Account`.
    init(account: Account) {
        self.init(
            statementPeriodStartDate: account.statementPeriodStartDate,
            statementClosingDate: account.statementClosingDate,
            paymentDueDate: account.paymentDueDate,
            lastConfirmedAt: account.statementScheduleLastConfirmedAt
        )
    }

    /// Writes the schedule values back onto an `Account` and bumps
    /// `lastUpdatedAt` so freshness queries stay honest.
    func apply(to account: Account, now: Date = .now) {
        account.statementPeriodStartDate = statementPeriodStartDate
        account.statementClosingDate = statementClosingDate
        account.paymentDueDate = paymentDueDate
        account.statementScheduleLastConfirmedAt = lastConfirmedAt
        account.lastUpdatedAt = now
    }
}

// MARK: - Derived state

extension CreditCardSchedule {

    /// True once every core date has been entered by the user. Last-
    /// confirmed timestamp is not required for completeness — it is a
    /// separate signal captured by ``state``.
    var isComplete: Bool {
        statementPeriodStartDate != nil
            && statementClosingDate != nil
            && paymentDueDate != nil
    }

    /// True when every pair of entered dates respects the expected
    /// ordering: start < closing < due. Missing dates never flip this
    /// to false because ordering can only be violated by adjacent
    /// fully-specified pairs.
    var hasValidDateOrder: Bool {
        dateOrderIssue == nil
    }

    /// Human-readable description of the first detected ordering
    /// problem, or nil if the (possibly partial) schedule is consistent.
    var dateOrderIssue: String? {
        if let start = statementPeriodStartDate,
           let closing = statementClosingDate,
           start >= closing {
            return "Statement closing date must be after the statement period start."
        }
        if let closing = statementClosingDate,
           let due = paymentDueDate,
           due < closing {
            return "Payment due date cannot be earlier than the statement closing date."
        }
        if let start = statementPeriodStartDate,
           let due = paymentDueDate,
           due <= start {
            return "Payment due date must be after the statement period start."
        }
        return nil
    }

    /// Coarse state used to drive the Settings badge.
    var state: CreditCardScheduleState {
        if !hasValidDateOrder { return .needsAttention }

        switch (isComplete, lastConfirmedAt) {
        case (false, _) where !hasAnyDate:
            return .missing
        case (false, _):
            return .partial
        case (true, .some):
            return .confirmed
        case (true, .none):
            return .partial
        }
    }

    /// True when at least one schedule date is non-nil. Used only
    /// internally by ``state`` to distinguish "missing" from "partial".
    private var hasAnyDate: Bool {
        statementPeriodStartDate != nil
            || statementClosingDate != nil
            || paymentDueDate != nil
    }
}
