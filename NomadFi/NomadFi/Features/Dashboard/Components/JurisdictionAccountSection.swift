import SwiftUI

/// A grouped section displaying accounts within a single jurisdiction.
///
/// Shows a flag + country name header with pinned section behavior,
/// followed by individual account cards using the `GlassCard` component.
struct JurisdictionAccountSection: View {

    let profile: JurisdictionProfile
    let accounts: [Account]

    var body: some View {
        Section {
            ForEach(accounts, id: \.self) { account in
                AccountCard(account: account)
            }
        } header: {
            sectionHeader
        }
    }
}

// MARK: - Subviews

private struct AccountCard: View {

    let account: Account

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard {
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
            .frame(width: 32)
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
            primaryAmountView

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

// MARK: - Private Helpers

private extension JurisdictionAccountSection {

    var sectionHeader: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            // Map country code to flag emoji
            Text(String.flagEmoji(for: profile.countryCode))
                .font(.title3)

            Text(profile.countryName)
                .font(TypographyTokens.sectionHeader)

            Spacer()

            if let currency = profile.currencyCode {
                Text(currency.rawValue)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.countryName) accounts")
        .accessibilityAddTraits(.isHeader)
    }

}

#Preview {
    let profile = JurisdictionProfile(
        countryCode: "US",
        countryName: "United States",
        currencyCode: .usd,
        isHome: false,
        displayOrder: 0
    )

    let accounts = [
        Account(
            name: "Sample Rewards",
            institutionName: "Sample Bank",
            accountType: .creditCard,
            currencyCode: .usd,
            jurisdiction: "US",
            creditLimit: 5_000,
            currentBalance: 350,
            availableCredit: 4_650,
            financialSnapshotUpdatedAt: .now,
            financialSnapshotSource: .userSnapshot
        ),
        Account(
            name: "Sample Checking",
            institutionName: "Sample Bank",
            accountType: .checking,
            currencyCode: .usd,
            jurisdiction: "US",
            currentBalance: 2_875,
            financialSnapshotUpdatedAt: .now,
            financialSnapshotSource: .userSnapshot
        ),
    ]

    ScrollView {
        LazyVStack(spacing: SpacingTokens.small, pinnedViews: .sectionHeaders) {
            JurisdictionAccountSection(profile: profile, accounts: accounts)
        }
        .padding()
    }
}
