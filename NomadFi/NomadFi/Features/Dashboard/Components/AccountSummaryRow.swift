import SwiftUI

/// One account on a country's page: name, institution, and its
/// balance with freshness.
struct AccountSummaryRow: View {

    let account: Account

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    accountInfo

                    balanceColumn
                }
            } else {
                HStack(spacing: SpacingTokens.small) {
                    accountIcon

                    accountInfo

                    Spacer()

                    balanceColumn
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accountIcon: some View {
        Image(systemName: account.accountType?.systemImage ?? "creditcard")
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .accessibilityHidden(true)
    }

    private var accountInfo: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(account.name)
                .font(TypographyTokens.sectionHeader)

            Text(account.institutionName)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var balanceColumn: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
            // The amount never wraps; the account name gives way instead.
            primaryAmountView
                .fixedSize()

            if let secondary = account.secondaryAmountLabel {
                Text(secondary.text)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            } else if let type = account.accountType {
                Text(type.displayName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            if snapshotFreshnessText != nil || account.isExcludedFromNetWorth {
                snapshotFreshnessBadge
            }
        }
    }

    @ViewBuilder
    private var primaryAmountView: some View {
        let primary = account.primaryAmountLabel
        switch primary.kind {
        case .currentBalance:
            if let amount = primary.rawAmount,
               let currency = account.currencyCode
            {
                if account.isCreditCard {
                    CurrencyText(
                        amount: amount,
                        currencyCode: currency,
                        font: TypographyTokens.amountMedium
                    )
                    .foregroundStyle(ColorTokens.negative)
                } else {
                    CurrencyText(
                        amount: amount,
                        currencyCode: currency,
                        font: TypographyTokens.amountMedium
                    )
                }
            } else {
                Text(primary.text)
                    .font(TypographyTokens.amountMedium)
            }
        case .balanceUnknown:
            Text(primary.text)
                .font(TypographyTokens.amountMedium)
                .foregroundStyle(.secondary)
        case .creditLimit, .availableCredit, .statementBalance:
            Text(primary.text)
                .font(TypographyTokens.amountMedium)
        }
    }

    private var snapshotFreshnessText: String? {
        guard account.hasFinancialSnapshot,
              let updatedAt = account.financialSnapshotUpdatedAt
        else { return nil }
        let date = updatedAt.formatted(.dateTime.year().month(.abbreviated).day())
        return account.isFinancialSnapshotStale() ? "Stale · \(date)" : "As of \(date)"
    }

    @ViewBuilder
    private var snapshotFreshnessBadge: some View {
        if account.isExcludedFromNetWorth {
            StatusBadge(
                label: "Not counted",
                color: ColorTokens.neutral,
                systemImage: "questionmark.circle"
            )
        } else if let text = snapshotFreshnessText {
            StatusBadge(
                label: text,
                color: account.isFinancialSnapshotStale() ? ColorTokens.warning : ColorTokens.neutral,
                systemImage: account.isFinancialSnapshotStale() ? "clock.badge.exclamationmark" : "clock"
            )
        }
    }

    private var accessibilityDescription: String {
        let primary = account.primaryAmountLabel
        var parts = ["\(account.name) at \(account.institutionName)", primary.accessibilityPhrase]
        if let secondary = account.secondaryAmountLabel {
            parts.append(secondary.accessibilityPhrase)
        }
        if account.isExcludedFromNetWorth {
            parts.append("not counted in net worth")
        } else if let text = snapshotFreshnessText {
            parts.append(text)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        AccountSummaryRow(
            account: Account(
                name: "Sample Checking",
                institutionName: "Sample Bank",
                accountType: .checking,
                currencyCode: .usd,
                jurisdiction: "US",
                currentBalance: 2_875,
                financialSnapshotUpdatedAt: .now,
                financialSnapshotSource: .userSnapshot
            )
        )
    }
}
