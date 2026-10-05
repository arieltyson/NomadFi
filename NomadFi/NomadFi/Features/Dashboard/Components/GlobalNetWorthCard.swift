import SwiftUI

/// The hero card displaying the user's total net worth in their home currency.
///
/// The total only: each country's figure lives on its own card below.
struct GlobalNetWorthCard: View {

    let totalNetWorth: Double
    let homeCurrency: CurrencyCode

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            headerRow

            primaryAmount
        }
        .padding(SpacingTokens.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ColorTokens.surfaceSecondary,
            in: .rect(cornerRadius: RadiusTokens.card, style: .continuous)
        )
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
    }
}

#Preview {
    GlobalNetWorthCard(totalNetWorth: 67_215.75, homeCurrency: .ttd)
        .padding()
}
