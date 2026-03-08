import SwiftUI

/// A single transaction row displaying merchant, category, amount, and jurisdiction.
///
/// Shows the original amount in its native currency with a secondary
/// home-currency equivalent when the transaction is cross-border.
struct TransactionRowView: View {

    let transaction: Transaction

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    merchantInfo

                    amountColumn
                }
            } else {
                HStack(spacing: SpacingTokens.small) {
                    categoryIcon

                    merchantInfo

                    Spacer()

                    amountColumn
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

private extension TransactionRowView {

    var categoryIcon: some View {
        Image(systemName: transaction.category?.systemImage ?? "ellipsis.circle")
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .frame(width: 32)
            .accessibilityHidden(true)
    }

    var merchantInfo: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(transaction.merchantName)
                .font(TypographyTokens.sectionHeader)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: SpacingTokens.xxSmall) {
                if !transaction.jurisdiction.isEmpty {
                    Text(String.flagEmoji(for: transaction.jurisdiction))
                }

                Text(transaction.category?.displayName ?? "Other")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var amountColumn: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: SpacingTokens.xxSmall) {
            if let currency = transaction.originalCurrency {
                CurrencyText(
                    amount: transaction.originalAmount,
                    currencyCode: currency,
                    font: TypographyTokens.amountSmall
                )
                .bold()
            }

            if isCrossBorder, let homeCurrency = transaction.homeCurrency {
                CurrencyText(
                    amount: transaction.convertedAmount,
                    currencyCode: homeCurrency,
                    font: TypographyTokens.caption
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    var isCrossBorder: Bool {
        transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue
            && transaction.convertedAmount != 0
    }

    var accessibilityDescription: String {
        let currency = transaction.originalCurrency?.rawValue ?? ""
        let amount = transaction.originalAmount.formatted(.currency(code: currency))
        let category = transaction.category?.displayName ?? "Other"
        return "\(transaction.merchantName), \(amount), \(category)"
    }

}

#Preview {
    List {
        TransactionRowView(
            transaction: Transaction(
                merchantName: "Whole Foods Market",
                originalAmount: -67.43,
                originalCurrency: .usd,
                convertedAmount: -457.19,
                homeCurrency: .ttd,
                appliedExchangeRate: 6.78,
                midMarketRate: 6.75,
                date: .now,
                category: .food,
                jurisdiction: "US"
            )
        )

        TransactionRowView(
            transaction: Transaction(
                merchantName: "Tim Hortons",
                originalAmount: -8.95,
                originalCurrency: .cad,
                date: .now,
                category: .food,
                jurisdiction: "CA"
            )
        )
    }
}
