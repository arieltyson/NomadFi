// SpendingTrendCard.swift
// NomadFi
//
// Read-only insight surface on the Dashboard. Shows where recent
// spending landed by category across a short month window. Never
// editable, never routed to the Ledger — tapping the card does not
// open a drilldown (by design: the Ledger is Advanced Tools only).
//
// The card is rendered only when `SpendingTrendComputer` returned a
// summary that cleared the "meaningful" floor, so presence itself
// is a signal the user has enough data for the trend to mean
// something.

import SwiftUI

/// A compact trend surface — one row per top spending category,
/// one column per recent month, plus a totals footer. Honest about
/// its caveats: if any transactions in the window used a different
/// currency, the card calls that out rather than silently dropping
/// them.
struct SpendingTrendCard: View {

    let summary: SpendingTrendSummary

    /// How many category rows the card surfaces. Anything beyond is
    /// collapsed into an implicit "and more" to keep the card calm.
    private let visibleRowLimit: Int = 4

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                header
                monthHeaderRow
                Divider()
                ForEach(visibleRows) { row in
                    categoryRow(row)
                }
                if hasHiddenRows {
                    hiddenRowsCaption
                }
                Divider()
                totalsRow
                if summary.skippedOtherCurrencyCount > 0 {
                    otherCurrencyCaveat
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Subviews

private extension SpendingTrendCard {

    var header: some View {
        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Where your money went")
                    .font(TypographyTokens.sectionHeader)
                Text("Last \(summary.months.count) \(summary.months.count == 1 ? "month" : "months") • \(summary.currencyCode.rawValue)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
        }
        .accessibilityAddTraits(.isHeader)
    }

    var monthHeaderRow: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Text("Category")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(summary.months, id: \.iso) { month in
                Text(shortMonthLabel(for: month))
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .trailing)
                    .accessibilityLabel(month.displayLabel())
            }
        }
    }

    func categoryRow(_ row: SpendingTrendCategoryRow) -> some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Label {
                Text(row.category.displayName)
                    .font(TypographyTokens.body)
                    .lineLimit(1)
            } icon: {
                Image(systemName: row.category.systemImage)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(row.totalsByMonth.enumerated()), id: \.offset) { _, amount in
                Text(currencyString(amount))
                    .font(TypographyTokens.body)
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(categoryAccessibilityLabel(for: row))
    }

    var hiddenRowsCaption: some View {
        Text("And \(hiddenRowCount) more \(hiddenRowCount == 1 ? "category" : "categories") with smaller totals.")
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
    }

    var totalsRow: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Text("Total")
                .font(TypographyTokens.sectionHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(summary.totalsByMonth.enumerated()), id: \.offset) { _, total in
                Text(currencyString(total))
                    .font(TypographyTokens.sectionHeader)
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(totalsAccessibilityLabel)
    }

    var otherCurrencyCaveat: some View {
        Label {
            Text("\(summary.skippedOtherCurrencyCount) \(summary.skippedOtherCurrencyCount == 1 ? "transaction was" : "transactions were") in another currency and \(summary.skippedOtherCurrencyCount == 1 ? "is" : "are") not shown.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

private extension SpendingTrendCard {

    var visibleRows: [SpendingTrendCategoryRow] {
        Array(summary.categoryRows.prefix(visibleRowLimit))
    }

    var hiddenRowCount: Int {
        max(0, summary.categoryRows.count - visibleRowLimit)
    }

    var hasHiddenRows: Bool {
        hiddenRowCount > 0
    }

    func currencyString(_ amount: Double) -> String {
        amount.formatted(.currency(code: summary.currencyCode.rawValue).precision(.fractionLength(0)))
    }

    func shortMonthLabel(for month: SpendingTrendMonth) -> String {
        var components = DateComponents()
        components.year = month.year
        components.month = month.month
        components.day = 1
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else { return month.iso }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    var accessibilityLabel: String {
        "Spending trend for the last \(summary.months.count) months in \(summary.currencyCode.rawValue)."
    }

    func categoryAccessibilityLabel(for row: SpendingTrendCategoryRow) -> String {
        let segments = zip(summary.months, row.totalsByMonth).map { month, amount in
            "\(month.displayLabel()): \(currencyString(amount))"
        }
        return "\(row.category.displayName). " + segments.joined(separator: ". ") + "."
    }

    var totalsAccessibilityLabel: String {
        let segments = zip(summary.months, summary.totalsByMonth).map { month, amount in
            "\(month.displayLabel()): \(currencyString(amount))"
        }
        return "Total. " + segments.joined(separator: ". ") + "."
    }
}

#Preview {
    let months: [SpendingTrendMonth] = [
        SpendingTrendMonth(year: 2026, month: 2),
        SpendingTrendMonth(year: 2026, month: 3),
        SpendingTrendMonth(year: 2026, month: 4),
    ]
    let rows: [SpendingTrendCategoryRow] = [
        SpendingTrendCategoryRow(
            category: .food,
            totalsByMonth: [320, 410, 385],
            totalForWindow: 1115
        ),
        SpendingTrendCategoryRow(
            category: .transport,
            totalsByMonth: [120, 90, 140],
            totalForWindow: 350
        ),
        SpendingTrendCategoryRow(
            category: .subscription,
            totalsByMonth: [45, 45, 60],
            totalForWindow: 150
        ),
    ]
    let summary = SpendingTrendSummary(
        months: months,
        categoryRows: rows,
        totalsByMonth: [485, 545, 585],
        currencyCode: .usd,
        contributingTransactionCount: 18,
        skippedOtherCurrencyCount: 2
    )
    return ScrollView {
        SpendingTrendCard(summary: summary)
            .padding()
    }
}
