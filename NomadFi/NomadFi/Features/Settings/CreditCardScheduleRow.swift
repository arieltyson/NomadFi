// CreditCardScheduleRow.swift
// NomadFi
//
// Compact Settings row showing a credit-card account and the current
// state of its statement calendar. Used inside a `Section` list, so
// the row relies on system list chrome rather than nesting custom
// cards.

import SwiftUI

/// A single row in the Credit Card Calendar section.
struct CreditCardScheduleRow: View {

    let account: Account

    private var schedule: CreditCardSchedule {
        CreditCardSchedule(account: account)
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(account.name)
                    .font(TypographyTokens.body)
                    .bold()

                Text(account.institutionName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                CreditCardScheduleDatePair(schedule: schedule)

                StatusBadge(
                    label: schedule.state.displayLabel,
                    color: Self.color(for: schedule.state),
                    systemImage: schedule.state.systemImage
                )
            }
        } icon: {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(for: account, schedule: schedule))
    }

    // MARK: - Semantic colour

    static func color(for state: CreditCardScheduleState) -> Color {
        switch state {
        case .missing: ColorTokens.neutral
        case .partial: ColorTokens.warning
        case .confirmed: ColorTokens.positive
        case .needsAttention: ColorTokens.negative
        }
    }

    // MARK: - VoiceOver

    static func accessibilityLabel(
        for account: Account,
        schedule: CreditCardSchedule
    ) -> String {
        var parts: [String] = [account.name, account.institutionName]

        if let closing = schedule.statementClosingDate {
            parts.append("statement closes \(Self.dateText(closing))")
        } else {
            parts.append("statement close date missing")
        }

        if let due = schedule.paymentDueDate {
            parts.append("payment due \(Self.dateText(due))")
        } else {
            parts.append("payment due date missing")
        }

        parts.append("status: \(schedule.state.displayLabel.lowercased())")
        return parts.joined(separator: ", ")
    }

    /// Absolute date rendering used for VoiceOver — HIG: avoid relative
    /// phrasing like "tomorrow" / "in 3 days".
    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day())
    }
}

/// Side-by-side close/due date summary. Extracted into its own view
/// struct so the parent row stays flat and the breakdown can be
/// previewed in isolation.
struct CreditCardScheduleDatePair: View {

    let schedule: CreditCardSchedule

    var body: some View {
        HStack(spacing: SpacingTokens.medium) {
            CreditCardScheduleDateColumn(
                title: "Close",
                date: schedule.statementClosingDate
            )
            CreditCardScheduleDateColumn(
                title: "Due",
                date: schedule.paymentDueDate
            )
        }
        .font(TypographyTokens.caption)
        .foregroundStyle(.secondary)
    }
}

/// A single labelled date column rendered inside ``CreditCardScheduleDatePair``.
struct CreditCardScheduleDateColumn: View {

    let title: String
    let date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(TypographyTokens.footnote)
                .foregroundStyle(.tertiary)

            if let date {
                Text(date, format: .dateTime.year().month(.abbreviated).day())
                    .monospacedDigit()
            } else {
                Text("Not set")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }
}

#Preview {
    List {
        Section("Credit Card Calendar") {
            CreditCardScheduleRow(
                account: .previewMissing
            )
            CreditCardScheduleRow(
                account: .previewConfirmed
            )
            CreditCardScheduleRow(
                account: .previewInvalid
            )
        }
    }
}

private extension Account {

    static var previewMissing: Account {
        Account(
            name: "Sample Cash Back",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US"
        )
    }

    static var previewConfirmed: Account {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 1))
        let closing = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 28))
        let due = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 25))
        return Account(
            name: "Sample Rewards",
            institutionName: "Example Credit Union",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            statementPeriodStartDate: start,
            statementClosingDate: closing,
            paymentDueDate: due,
            statementScheduleLastConfirmedAt: Date(timeIntervalSince1970: 1_734_000_000)
        )
    }

    static var previewInvalid: Account {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 1))
        let closing = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 28))
        let invalidDue = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15))
        return Account(
            name: "Sample Travel",
            institutionName: "Example Co-op",
            accountType: .creditCard,
            currencyCode: .cad,
            jurisdiction: "CA",
            statementPeriodStartDate: start,
            statementClosingDate: closing,
            paymentDueDate: invalidDue
        )
    }
}
