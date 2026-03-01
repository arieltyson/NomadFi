// SubscriptionRowView.swift
// NomadFi
//
// Displays a single tracked subscription with service name, amount,
// frequency, renewal date, and jurisdiction flag.

import SwiftData
import SwiftUI

/// A single subscription row showing service details and renewal info.
///
/// Displays the subscription amount in its native currency with a
/// home-currency equivalent, renewal countdown, and savings badge
/// when a cheaper jurisdiction exists.
struct SubscriptionRowView: View {

    let subscription: Subscription
    let homeCurrency: CurrencyCode

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    serviceInfo

                    amountColumn
                }
            } else {
                HStack(spacing: SpacingTokens.small) {
                    serviceIcon

                    serviceInfo

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

private extension SubscriptionRowView {

    var serviceIcon: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .frame(width: 32)
            .accessibilityHidden(true)
    }

    var serviceInfo: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(subscription.serviceName)
                .font(TypographyTokens.sectionHeader)
                .lineLimit(1)

            HStack(spacing: SpacingTokens.xxSmall) {
                if !subscription.jurisdiction.isEmpty {
                    Text(String.flagEmoji(for: subscription.jurisdiction))
                }

                if let frequency = subscription.frequency {
                    Text(frequency.displayName)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            renewalInfo
        }
    }

    var renewalInfo: some View {
        HStack(spacing: SpacingTokens.xxSmall) {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("Renews \(subscription.nextRenewalDate, format: .dateTime.month(.abbreviated).day())")
                .font(TypographyTokens.caption)
                .foregroundStyle(.tertiary)
        }
    }

    var amountColumn: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
            if let currency = subscription.currencyCode {
                CurrencyText(
                    amount: subscription.amount,
                    currencyCode: currency,
                    font: TypographyTokens.amountSmall
                )
                .bold()
            }

            if subscription.monthlySavings > 0 {
                Text("Save \(subscription.monthlySavings, format: .currency(code: homeCurrency.rawValue))/mo")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.positive)
                    .bold()
            }
        }
    }

    var accessibilityDescription: String {
        let currency = subscription.currencyCode?.rawValue ?? "USD"
        let amount = subscription.amount.formatted(.currency(code: currency))
        let frequency = subscription.frequency?.displayName ?? "recurring"
        let renewal = subscription.nextRenewalDate.formatted(date: .abbreviated, time: .omitted)
        var description = "\(subscription.serviceName), \(amount) \(frequency), renews \(renewal)"
        if subscription.monthlySavings > 0 {
            let savings = subscription.monthlySavings.formatted(.currency(code: homeCurrency.rawValue))
            description += ", save \(savings) per month by switching jurisdictions"
        }
        return description
    }

}

#Preview {
    VStack(spacing: SpacingTokens.small) {
        SubscriptionRowView(
            subscription: Subscription(
                serviceName: "Netflix",
                amount: 15.49,
                currencyCode: .usd,
                frequency: .monthly,
                nextRenewalDate: Calendar.current.date(byAdding: .day, value: 12, to: .now) ?? .now,
                jurisdiction: "US"
            ),
            homeCurrency: .usd
        )

        SubscriptionRowView(
            subscription: Subscription(
                serviceName: "Spotify",
                amount: 11.99,
                currencyCode: .cad,
                frequency: .monthly,
                nextRenewalDate: Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now,
                jurisdiction: "CA",
                homeCurrencyEquivalent: 8.99,
                cheapestAlternativeAmount: 29.99,
                cheapestAlternativeCurrency: .ttd,
                cheapestAlternativeJurisdiction: "TT"
            ),
            homeCurrency: .usd
        )
    }
    .padding()
    .modelContainer(for: Subscription.self, inMemory: true)
}
