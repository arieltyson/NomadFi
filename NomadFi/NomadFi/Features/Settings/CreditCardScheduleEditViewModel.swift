// CreditCardScheduleEditViewModel.swift
// NomadFi
//
// Backing view model for `CreditCardScheduleEditView`. Holds mirrors
// of the account's schedule fields so the editor can toggle dates on
// and off without losing intermediate values, and keeps validation
// logic out of the view.

import Foundation

/// View model for editing a single credit card's statement calendar.
///
/// The editor exposes each of the three core dates through a Toggle +
/// DatePicker pair. The VM keeps a non-optional "working value" for
/// every DatePicker and a separate boolean for its enabled state, so
/// toggling off a date doesn't lose the most recently entered value.
@MainActor
@Observable
final class CreditCardScheduleEditViewModel {

    // MARK: - Anchors

    /// The persisted account being edited. Held as a reference so that
    /// mutations flow through SwiftData autosave.
    let account: Account

    // MARK: - Working values

    var hasStatementPeriodStartDate: Bool
    var statementPeriodStartWorkingDate: Date

    var hasStatementClosingDate: Bool
    var statementClosingWorkingDate: Date

    var hasPaymentDueDate: Bool
    var paymentDueWorkingDate: Date

    /// Whether the user currently considers the schedule confirmed.
    /// Flipping this on stamps ``CreditCardSchedule/lastConfirmedAt``
    /// to "now" at save time; flipping it off clears the stamp.
    var isMarkedAsConfirmed: Bool

    /// Clock used when stamping `lastConfirmedAt`. Parameterised so
    /// tests can pin the value.
    private let clock: @Sendable () -> Date

    // MARK: - Init

    init(
        account: Account,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.account = account
        self.clock = clock

        let today = clock()
        let existing = CreditCardSchedule(account: account)

        self.hasStatementPeriodStartDate = existing.statementPeriodStartDate != nil
        self.statementPeriodStartWorkingDate = existing.statementPeriodStartDate ?? today

        self.hasStatementClosingDate = existing.statementClosingDate != nil
        self.statementClosingWorkingDate = existing.statementClosingDate
            ?? Self.defaultClosing(from: existing.statementPeriodStartDate ?? today)

        self.hasPaymentDueDate = existing.paymentDueDate != nil
        self.paymentDueWorkingDate = existing.paymentDueDate
            ?? Self.defaultDue(from: existing.statementClosingDate ?? today)

        self.isMarkedAsConfirmed = existing.lastConfirmedAt != nil
    }

    // MARK: - Derived

    /// Live snapshot used for the status badge preview and validation.
    var pendingSchedule: CreditCardSchedule {
        CreditCardSchedule(
            statementPeriodStartDate: hasStatementPeriodStartDate
                ? statementPeriodStartWorkingDate
                : nil,
            statementClosingDate: hasStatementClosingDate
                ? statementClosingWorkingDate
                : nil,
            paymentDueDate: hasPaymentDueDate
                ? paymentDueWorkingDate
                : nil,
            lastConfirmedAt: isMarkedAsConfirmed ? account.statementScheduleLastConfirmedAt : nil
        )
    }

    /// The first detected ordering problem in the current working
    /// values, or nil when the (possibly partial) schedule is consistent.
    var validationIssue: String? {
        pendingSchedule.dateOrderIssue
    }

    /// Whether the current working values can be persisted. Prevents
    /// saving a definitely-wrong schedule.
    var canSave: Bool {
        validationIssue == nil
    }

    // MARK: - Mutations

    /// Writes the current working values onto the persisted account.
    /// Stamps `lastConfirmedAt` when the user checked "mark as
    /// confirmed" and clears it otherwise.
    func save() {
        let lastConfirmed: Date?
        if isMarkedAsConfirmed {
            lastConfirmed = account.statementScheduleLastConfirmedAt ?? clock()
        } else {
            lastConfirmed = nil
        }

        var schedule = pendingSchedule
        schedule.lastConfirmedAt = lastConfirmed
        schedule.apply(to: account, now: clock())
    }

    /// Stamps `lastConfirmedAt` to now (via the injected clock).
    func markConfirmedNow() {
        isMarkedAsConfirmed = true
        account.statementScheduleLastConfirmedAt = clock()
    }

    /// Clears every schedule field — toggles, working dates, and the
    /// confirmation stamp. Does not immediately persist; the caller is
    /// expected to follow up with ``save()``.
    func clearAll() {
        hasStatementPeriodStartDate = false
        hasStatementClosingDate = false
        hasPaymentDueDate = false
        isMarkedAsConfirmed = false

        let today = clock()
        statementPeriodStartWorkingDate = today
        statementClosingWorkingDate = Self.defaultClosing(from: today)
        paymentDueWorkingDate = Self.defaultDue(from: today)
    }

    // MARK: - Default suggestions

    /// A reasonable default closing date when one has not yet been
    /// entered — four weeks after the supplied anchor. The user is
    /// expected to refine this to match their issuer app.
    private static func defaultClosing(from anchor: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 28, to: anchor) ?? anchor
    }

    /// A reasonable default due date — three weeks after the closing
    /// anchor. Again, a starting value only; the user edits this.
    private static func defaultDue(from anchor: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 21, to: anchor) ?? anchor
    }
}
