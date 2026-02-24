import SwiftUI

/// Displays the "Real Cost" breakdown for a cross-border transaction.
///
/// Compares the actual cost (using the applied exchange rate) against the
/// fair cost (using the mid-market rate), highlighting the FX markup delta.
/// Color-coded: green for fair, yellow for slight markup, red for significant.
struct RealCostCard: View {

    let fairCost: Double
    let actualCost: Double
    let delta: Double
    let homeCurrency: CurrencyCode

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                headerRow

                costComparison

                if abs(delta) > 0.01 {
                    deltaRow
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Private Helpers

private extension RealCostCard {

    var headerRow: some View {
        Label("Real Cost Analysis", systemImage: "arrow.triangle.swap")
            .font(TypographyTokens.sectionHeader)
    }

    var costComparison: some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Fair Cost")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                CurrencyText(
                    amount: fairCost,
                    currencyCode: homeCurrency,
                    font: TypographyTokens.amountSmall
                )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
                Text("You Paid")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                CurrencyText(
                    amount: actualCost,
                    currencyCode: homeCurrency,
                    font: TypographyTokens.amountSmall
                )
                .bold()
            }
        }
    }

    var deltaRow: some View {
        HStack {
            Image(systemName: delta > 0 ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(deltaColor)

            if delta > 0 {
                Text("You overpaid by \(delta, format: .currency(code: homeCurrency.rawValue))")
                    .font(TypographyTokens.body)
                    .foregroundStyle(deltaColor)
            } else {
                Text("You saved \(abs(delta), format: .currency(code: homeCurrency.rawValue))")
                    .font(TypographyTokens.body)
                    .foregroundStyle(deltaColor)
            }
        }
    }

    var deltaColor: Color {
        ColorTokens.fxMarkupColor(for: delta)
    }

    var accessibilityDescription: String {
        let fairFormatted = fairCost.formatted(.currency(code: homeCurrency.rawValue))
        let actualFormatted = actualCost.formatted(.currency(code: homeCurrency.rawValue))
        let deltaFormatted = abs(delta).formatted(.currency(code: homeCurrency.rawValue))

        if delta > 0 {
            return "Real cost analysis. Fair cost \(fairFormatted), you paid \(actualFormatted), overpaid by \(deltaFormatted)"
        } else {
            return "Real cost analysis. Fair cost \(fairFormatted), you paid \(actualFormatted), saved \(deltaFormatted)"
        }
    }
}

#Preview {
    VStack(spacing: SpacingTokens.medium) {
        RealCostCard(fairCost: 453.99, actualCost: 457.19, delta: 3.20, homeCurrency: .ttd)
        RealCostCard(fairCost: 67.43, actualCost: 67.43, delta: 0, homeCurrency: .usd)
        RealCostCard(fairCost: 100.00, actualCost: 97.50, delta: -2.50, homeCurrency: .usd)
    }
    .padding()
}
