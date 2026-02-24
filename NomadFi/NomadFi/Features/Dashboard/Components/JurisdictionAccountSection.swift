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

    var body: some View {
        GlassCard {
            HStack(spacing: SpacingTokens.small) {
                accountIcon

                accountInfo

                Spacer()

                balanceColumn
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
            if let currency = account.currencyCode {
                CurrencyText(
                    amount: account.balance,
                    currencyCode: currency,
                    font: TypographyTokens.amountMedium
                )
            }

            if let type = account.accountType {
                Text(type.displayName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilityDescription: String {
        let currency = account.currencyCode?.rawValue ?? ""
        let formatted = account.balance.formatted(.currency(code: currency))
        return "\(account.name) at \(account.institutionName), balance \(formatted)"
    }
}

// MARK: - Private Helpers

private extension JurisdictionAccountSection {

    var sectionHeader: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            // Map country code to flag emoji
            Text(flagEmoji(for: profile.countryCode))
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
    }

    /// Converts an ISO 3166-1 alpha-2 code to its regional indicator emoji.
    func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { Unicode.Scalar(base + $0.value) }
            .map { String($0) }
            .joined()
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
            name: "Chase Freedom Rise",
            institutionName: "JPMorgan Chase",
            accountType: .creditCard,
            currencyCode: .usd,
            balance: 1_250.00,
            jurisdiction: "US"
        ),
        Account(
            name: "Chase Checking",
            institutionName: "JPMorgan Chase",
            accountType: .checking,
            currencyCode: .usd,
            balance: 2_875.00,
            jurisdiction: "US"
        ),
    ]

    ScrollView {
        LazyVStack(spacing: SpacingTokens.small, pinnedViews: .sectionHeaders) {
            JurisdictionAccountSection(profile: profile, accounts: accounts)
        }
        .padding()
    }
}
