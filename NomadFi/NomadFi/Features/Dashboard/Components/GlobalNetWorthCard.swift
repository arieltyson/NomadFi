import SwiftUI

/// The hero card displaying the user's total net worth in their home currency.
///
/// Shows the primary amount with an animated counting transition,
/// plus secondary amounts in each jurisdiction's local currency.
/// Uses Liquid Glass material for iOS 26 aesthetic.
struct GlobalNetWorthCard: View {

    let totalNetWorth: Double
    let homeCurrency: CurrencyCode
    let jurisdictionTotals: [(code: String, name: String, amount: Double, currency: CurrencyCode)]

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            headerRow

            primaryAmount

            if !jurisdictionTotals.isEmpty {
                Divider()

                jurisdictionBreakdown
            }
        }
        .padding(SpacingTokens.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: SpacingTokens.medium))
    }
}

// MARK: - Subviews

private struct JurisdictionAmountRow: View {

    let name: String
    let amount: Double
    let currency: CurrencyCode

    var body: some View {
        HStack {
            Text(name)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)

            Spacer()

            CurrencyText(amount: amount, currencyCode: currency, font: TypographyTokens.amountSmall)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Private Helpers

private extension GlobalNetWorthCard {

    var headerRow: some View {
        HStack {
            Text("Global Net Worth")
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Image(systemName: "globe")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
        }
    }

    var primaryAmount: some View {
        CurrencyText(
            amount: totalNetWorth,
            currencyCode: homeCurrency,
            font: TypographyTokens.amountLarge
        )
        .bold()
        .accessibilityLabel("Total net worth")
    }

    var jurisdictionBreakdown: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(jurisdictionTotals, id: \.code) { item in
                JurisdictionAmountRow(
                    name: item.name,
                    amount: item.amount,
                    currency: item.currency
                )
            }
        }
    }

    @ViewBuilder
    var cardBackground: some View {
        if reduceTransparency {
            ColorTokens.surfaceSecondary
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        Rectangle().fill(Color.teal.gradient).ignoresSafeArea()

        GlobalNetWorthCard(
            totalNetWorth: 67_215.75,
            homeCurrency: .ttd,
            jurisdictionTotals: [
                (code: "TT", name: "Trinidad & Tobago", amount: 25_000.00, currency: .ttd),
                (code: "CA", name: "Canada", amount: 8_750.25, currency: .cad),
                (code: "US", name: "United States", amount: 4_125.00, currency: .usd),
            ]
        )
        .padding()
    }
}
