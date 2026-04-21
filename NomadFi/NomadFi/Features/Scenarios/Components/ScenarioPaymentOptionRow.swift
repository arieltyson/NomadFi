// ScenarioPaymentOptionRow.swift
// NomadFi
//
// A single row in the payment-option comparison inside the Scenario
// Decision Brief detail sheet. Kept as its own file so the sheet stays
// readable.

import SwiftUI

/// Renders one `ScenarioPaymentOption` with its stance badge,
/// upside/downside, and evidence tags.
struct ScenarioPaymentOptionRow: View {

    let option: ScenarioPaymentOption

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Text(option.title)
                        .font(TypographyTokens.sectionHeader)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: SpacingTokens.xSmall)

                    stanceBadge
                }

                Text(option.subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(option.costLabel)
                    .font(TypographyTokens.amountSmall)
                    .bold()

                labelledParagraph(title: "Upside", text: option.upside)
                labelledParagraph(title: "Downside / risk", text: option.downside)

                if !option.evidence.isEmpty {
                    HStack(spacing: SpacingTokens.xxSmall) {
                        ForEach(option.evidence, id: \.self) { tag in
                            ScenarioEvidenceBadge(tag: tag)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityNarrative)
    }

    // MARK: - Private helpers

    @ViewBuilder
    private func labelledParagraph(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(title)
                .font(TypographyTokens.caption)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stanceBadge: some View {
        StatusBadge(
            label: stanceLabel,
            color: stanceColor,
            systemImage: stanceSystemImage
        )
    }

    private var stanceLabel: String {
        switch option.stance {
        case .conditionallyPreferred: "Conditional pick"
        case .safeFallback: "Safe fallback"
        case .needsVerification: "Needs verification"
        case .discouraged: "Discouraged"
        }
    }

    private var stanceColor: Color {
        switch option.stance {
        case .conditionallyPreferred: ColorTokens.positive
        case .safeFallback: ColorTokens.brandPrimary
        case .needsVerification: ColorTokens.warning
        case .discouraged: ColorTokens.negative
        }
    }

    private var stanceSystemImage: String {
        switch option.stance {
        case .conditionallyPreferred: "checkmark.circle"
        case .safeFallback: "shield.lefthalf.filled"
        case .needsVerification: "exclamationmark.circle"
        case .discouraged: "xmark.octagon"
        }
    }

    private var accessibilityNarrative: String {
        "\(option.title). Stance: \(stanceLabel). Cost: \(option.costLabel). Upside: \(option.upside). Downside: \(option.downside)."
    }
}
