// SavingsOpportunityCard.swift
// NomadFi
//
// Displays a cross-border subscription savings opportunity
// with current vs. cheapest pricing comparison.

import SwiftUI

/// A card highlighting a subscription savings opportunity through cross-border pricing.
///
/// Shows the current subscription cost versus the cheapest alternative jurisdiction,
/// with the potential monthly and annual savings prominently displayed.
struct SavingsOpportunityCard: View {

    let result: SubscriptionComparisonEngine.ComparisonResult
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                header

                pricingComparison

                savingsBanner
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

extension SavingsOpportunityCard {

    fileprivate var header: some View {
        let increasedContrast = colorSchemeContrast == .increased

        return HStack {
            Image(systemName: "arrow.2.squarepath")
                .foregroundStyle(ColorTokens.positive)
                .accessibilityHidden(true)

            Text(result.serviceName)
                .font(TypographyTokens.sectionHeader)

            Spacer()

            Text("Arbitrage")
                .font(.caption2)
                .bold()
                .padding(.horizontal, SpacingTokens.xSmall)
                .padding(.vertical, SpacingTokens.xxSmall)
                .background(
                    ColorTokens.tintedFill(ColorTokens.positive, contrast: colorSchemeContrast)
                )
                .foregroundStyle(
                    increasedContrast ? .primary : ColorTokens.positive
                )
                .overlay {
                    if increasedContrast {
                        Capsule()
                            .strokeBorder(ColorTokens.positive, lineWidth: 1)
                    }
                }
                .clipShape(.capsule)
        }
    }

    fileprivate var pricingComparison: some View {
        let currentColumn = VStack(
            alignment: .leading,
            spacing: SpacingTokens.xxSmall
        ) {
            Text(
                "Current (\(String.flagEmoji(for: result.currentJurisdiction)))"
            )
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)

            Text(
                result.currentAmount,
                format: .money(code: result.currentCurrency.rawValue)
            )
            .font(TypographyTokens.amountSmall)
            .strikethrough(color: ColorTokens.negative)
            .foregroundStyle(ColorTokens.negative)
        }

        let cheaperColumn = VStack(
            alignment: .leading,
            spacing: SpacingTokens.xxSmall
        ) {
            Text(
                "Cheaper (\(String.flagEmoji(for: result.cheapestJurisdiction)))"
            )
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)

            Text(
                result.cheapestAmount,
                format: .money(code: result.cheapestCurrency.rawValue)
            )
            .font(TypographyTokens.amountSmall)
            .foregroundStyle(ColorTokens.positive)
            .bold()
        }

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    currentColumn

                    Image(systemName: "arrow.down")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)

                    cheaperColumn
                }
            } else {
                HStack(spacing: SpacingTokens.medium) {
                    currentColumn

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)

                    cheaperColumn
                }
            }
        }
    }

    fileprivate var savingsBanner: some View {
        let increasedContrast = colorSchemeContrast == .increased

        return HStack(spacing: SpacingTokens.xSmall) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(ColorTokens.positive)

            Text(
                "Save \(result.annualSavingsInHomeCurrency, format: .money(code: result.homeCurrency.rawValue))/year"
            )
            .font(TypographyTokens.caption)
            .foregroundStyle(
                increasedContrast ? .primary : ColorTokens.positive
            )
            .bold()
        }
        .padding(SpacingTokens.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ColorTokens.tintedSurface(ColorTokens.positive, contrast: colorSchemeContrast)
        )
        .overlay {
            if increasedContrast {
                RoundedRectangle(cornerRadius: RadiusTokens.small, style: .continuous)
                    .strokeBorder(ColorTokens.positive, lineWidth: 1)
            }
        }
        .clipShape(.rect(cornerRadius: RadiusTokens.small, style: .continuous))
    }
}

// MARK: - Helpers

extension SavingsOpportunityCard {

    fileprivate var accessibilityDescription: String {
        let current = result.currentAmount.formatted(
            .money(code: result.currentCurrency.rawValue)
        )
        let cheaper = result.cheapestAmount.formatted(
            .money(code: result.cheapestCurrency.rawValue)
        )
        let savings = result.annualSavingsInHomeCurrency.formatted(
            .money(code: result.homeCurrency.rawValue)
        )
        return
            "\(result.serviceName): currently \(current) in \(result.currentJurisdiction). Switch to \(result.cheapestJurisdiction) for \(cheaper). Save \(savings) per year."
    }

}

#Preview {
    VStack(spacing: SpacingTokens.small) {
        SavingsOpportunityCard(
            result: SubscriptionComparisonEngine.ComparisonResult(
                serviceName: "Netflix",
                currentAmount: 15.49,
                currentCurrency: .usd,
                currentJurisdiction: "US",
                cheapestAmount: 16.99,
                cheapestCurrency: .cad,
                cheapestJurisdiction: "CA",
                monthlySavingsInHomeCurrency: 3.48,
                annualSavingsInHomeCurrency: 41.76,
                homeCurrency: .usd
            )
        )
    }
    .padding()
}
