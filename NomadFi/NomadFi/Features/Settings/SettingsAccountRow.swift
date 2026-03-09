import SwiftUI

/// A compact account summary row used in Settings > Accounts.
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
                Text(account.name)
                    .font(TypographyTokens.body)
                    .bold()

                Text(account.institutionName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
                Text(account.currencyCodeRawValue)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                Text(
                    account.balance,
                    format: .currency(code: account.currencyCodeRawValue)
                )
                .font(TypographyTokens.body)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        "\(account.name), \(account.institutionName), balance \(account.balance.formatted(.currency(code: account.currencyCodeRawValue)))"
    }
}
