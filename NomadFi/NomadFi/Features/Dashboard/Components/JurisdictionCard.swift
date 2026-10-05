// JurisdictionCard.swift
// NomadFi
//
// One country on the Dashboard: flag, name and total.

import SwiftUI

/// A country's card on the Dashboard — flag, name, and its total in
/// local currency. The whole card is the link to the country's page,
/// where its accounts and transactions live.
struct JurisdictionCard: View {

    let summary: JurisdictionSummary

    var body: some View {
        // Always two lines — name above, amount below — so every card
        // has the same shape whatever the currency's length, and grows
        // naturally with Dynamic Type.
        SurfaceCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                HStack(spacing: SpacingTokens.xSmall) {
                    CountryName(profile: summary.profile)
                    Spacer(minLength: SpacingTokens.xSmall)
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                Total(summary: summary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(summary.profile.countryName), \(summary.total.formatted(.currency(code: summary.currency.rawValue)))"
        )
    }
}

/// Flag and country name.
private struct CountryName: View {

    let profile: JurisdictionProfile

    var body: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Text(String.flagEmoji(for: profile.countryCode))
                .font(.title2)
            Text(profile.countryName)
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(.secondary)
        }
    }
}

/// The country's total in its own currency.
private struct Total: View {

    let summary: JurisdictionSummary

    var body: some View {
        CurrencyText(
            amount: summary.total,
            currencyCode: summary.currency,
            font: TypographyTokens.amountMedium
        )
        .bold()
        .foregroundStyle(.primary)
    }
}

#Preview {
    JurisdictionCard(
        summary: JurisdictionSummary(
            profile: JurisdictionProfile(
                countryCode: "CA",
                countryName: "Canada",
                currencyCode: .cad,
                isHome: false,
                displayOrder: 0
            ),
            accounts: []
        )
    )
    .padding()
}
