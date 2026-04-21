import SwiftUI

/// A horizontally scrolling ticker displaying live exchange rate pairs.
///
/// Shows relevant FX pairs derived from the user's jurisdictions
/// with rate value and directional trend indicator.
struct ExchangeRateTicker: View {

    let rates: [ExchangeRateSnapshot]
    let lastUpdated: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            headerRow

            if rates.isEmpty {
                emptyState
            } else {
                rateScroller
            }
        }
    }
}

// MARK: - Subviews

private struct RateCard: View {

    let rate: ExchangeRateSnapshot
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text("\(rate.baseCurrency.rawValue) \u{2192} \(rate.targetCurrency.rawValue)")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)

            Text(rate.rate, format: .number.precision(.fractionLength(2...4)))
                .font(TypographyTokens.amountSmall)
                .bold()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.xSmall)
        .background {
            if reduceTransparency {
                ColorTokens.surfaceSecondary
            } else {
                Rectangle().fill(.thinMaterial)
            }
        }
        .clipShape(.rect(cornerRadius: SpacingTokens.xSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("1 \(rate.baseCurrency.displayName) equals \(rate.rate.formatted(.number.precision(.fractionLength(2)))) \(rate.targetCurrency.displayName)")
    }
}

// MARK: - Private Helpers

private extension ExchangeRateTicker {

    /// Derives a single confidence label for the whole ticker from the
    /// snapshots currently displayed. When every snapshot shares the same
    /// confidence (the normal case for a single fetch), we surface it;
    /// otherwise we fall back to the weakest label to avoid overstating
    /// the data.
    var tickerConfidence: SourceConfidence? {
        guard let first = rates.first?.sourceProvenance.confidence else { return nil }
        let allSame = rates.allSatisfy { $0.sourceProvenance.confidence == first }
        return allSame ? first : .indicative
    }

    var confidenceBadge: some View {
        Group {
            if let tickerConfidence {
                StatusBadge(
                    label: tickerConfidence.displayLabel,
                    color: tickerConfidence.isVerified ? ColorTokens.positive : ColorTokens.warning,
                    systemImage: tickerConfidence.isVerified ? "checkmark.seal" : "info.circle"
                )
                .accessibilityLabel("Rates confidence: \(tickerConfidence.displayLabel)")
            }
        }
    }

    var headerRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Label("Exchange Rates", systemImage: "chart.line.uptrend.xyaxis")
                        .font(TypographyTokens.sectionHeader)
                        .accessibilityAddTraits(.isHeader)

                    confidenceBadge

                    if let lastUpdated {
                        Text("Updated \(lastUpdated, format: .dateTime.hour().minute())")
                            .font(TypographyTokens.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                HStack(spacing: SpacingTokens.xSmall) {
                    Label("Exchange Rates", systemImage: "chart.line.uptrend.xyaxis")
                        .font(TypographyTokens.sectionHeader)
                        .accessibilityAddTraits(.isHeader)

                    confidenceBadge

                    Spacer()

                    if let lastUpdated {
                        Text("Updated \(lastUpdated, format: .dateTime.hour().minute())")
                            .font(TypographyTokens.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    var rateScroller: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: SpacingTokens.xSmall) {
                ForEach(rates, id: \.baseCurrency) { rate in
                    RateCard(rate: rate)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    var emptyState: some View {
        Text("Rates loading\u{2026}")
            .font(TypographyTokens.caption)
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    let sampleProvenance = SourceProvenance.sampleRates(accessedAt: .now)
    ExchangeRateTicker(
        rates: [
            ExchangeRateSnapshot(baseCurrency: .usd, targetCurrency: .ttd, rate: 6.78, fetchedAt: .now, sourceProvenance: sampleProvenance),
            ExchangeRateSnapshot(baseCurrency: .usd, targetCurrency: .cad, rate: 1.36, fetchedAt: .now, sourceProvenance: sampleProvenance),
            ExchangeRateSnapshot(baseCurrency: .cad, targetCurrency: .ttd, rate: 4.99, fetchedAt: .now, sourceProvenance: sampleProvenance),
        ],
        lastUpdated: .now
    )
    .padding()
}
