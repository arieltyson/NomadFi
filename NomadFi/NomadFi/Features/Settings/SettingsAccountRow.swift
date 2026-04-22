import SwiftUI

/// A compact account summary row used in Settings > Accounts.
///
/// The row renders account-type-aware amount copy: credit cards show a
/// "Limit" and an amount-owed (or "Balance not set"), while deposit/
/// wallet/investment accounts show a single latest-balance line. A
/// credit *limit* is never labelled as a "balance" — in text or in
/// VoiceOver.
struct SettingsAccountRow: View {

    let account: Account

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: account.accountType?.systemImage ?? "creditcard")
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                nameRow

                Text(account.institutionName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                if shouldShowFreshnessRow {
                    freshnessRow
                }
            }

            Spacer(minLength: 0)

            amountColumn
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

private extension SettingsAccountRow {

    /// Account name plus, for credit cards, an inline SF-symbol chip.
    /// At accessibility text sizes the chip wraps below the name so
    /// nothing is clipped; the name itself is never truncated.
    @ViewBuilder
    var nameRow: some View {
        if account.isCreditCard, let type = account.accountType {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Text(account.name)
                        .font(TypographyTokens.body)
                        .bold()
                    AccountTypeMarker(accountType: type)
                }
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(account.name)
                        .font(TypographyTokens.body)
                        .bold()
                    AccountTypeMarker(accountType: type)
                }
            }
        } else {
            Text(account.name)
                .font(TypographyTokens.body)
                .bold()
        }
    }

    var amountColumn: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
            Text(account.currencyCodeRawValue)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)

            primaryAmountView

            if let secondary = account.secondaryAmountLabel {
                Text(secondary.text)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var primaryAmountView: some View {
        let primary = account.primaryAmountLabel
        switch primary.kind {
        case .balanceUnknown:
            Text(primary.text)
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .italic()
        case .currentBalance:
            Text(primary.text)
                .font(TypographyTokens.body)
                .foregroundStyle(
                    account.isCreditCard ? ColorTokens.negative : Color.primary
                )
        case .creditLimit, .availableCredit, .statementBalance:
            Text(primary.text)
                .font(TypographyTokens.body)
        }
    }

    var shouldShowFreshnessRow: Bool {
        account.isExcludedFromNetWorth || account.financialSnapshotUpdatedAt != nil
    }

    @ViewBuilder
    var freshnessRow: some View {
        if account.isExcludedFromNetWorth {
            StatusBadge(
                label: "Balance not set",
                color: ColorTokens.warning,
                systemImage: "questionmark.circle"
            )
        } else if let updatedAt = account.financialSnapshotUpdatedAt {
            let dateText = updatedAt.formatted(.dateTime.year().month(.abbreviated).day())
            let isStale = account.isFinancialSnapshotStale()
            StatusBadge(
                label: isStale ? "Stale · \(dateText)" : "As of \(dateText)",
                color: isStale ? ColorTokens.warning : ColorTokens.neutral,
                systemImage: isStale ? "clock.badge.exclamationmark" : "clock"
            )
        }
    }

    /// VoiceOver phrasing. Never calls a credit limit a balance, and
    /// always names the account type so users relying on VoiceOver do
    /// not need the visual chip to identify a card.
    var accessibilityDescription: String {
        var parts: [String] = [account.name]
        if let type = account.accountType {
            parts.append(AccountTypeMarker.accessibilityPhrase(for: type))
        }
        parts.append(account.institutionName)

        let primary = account.primaryAmountLabel
        parts.append(primary.accessibilityPhrase)

        if let secondary = account.secondaryAmountLabel {
            parts.append(secondary.accessibilityPhrase)
        }

        if account.isExcludedFromNetWorth {
            parts.append("not counted in net worth")
        } else if let updatedAt = account.financialSnapshotUpdatedAt {
            let dateText = updatedAt.formatted(.dateTime.year().month(.wide).day())
            let isStale = account.isFinancialSnapshotStale()
            parts.append(isStale ? "snapshot is stale, last updated \(dateText)" : "snapshot from \(dateText)")
        }

        return parts.joined(separator: ", ")
    }
}
