// DetectedSubscriptionCard.swift
// NomadFi
//
// Displays a newly detected subscription candidate with
// confirm and dismiss actions.

import SwiftUI

/// A card displaying a detected subscription candidate for user confirmation.
///
/// Shows the detected merchant, amount, frequency, and confidence level.
/// The user can confirm to start tracking or dismiss the detection.
struct DetectedSubscriptionCard: View {

    let detection: SubscriptionDetector.DetectedSubscription
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                detectionHeader

                detectionDetails

                actionButtons
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Subviews

extension DetectedSubscriptionCard {

    fileprivate var detectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(detection.merchantName)
                    .font(TypographyTokens.sectionHeader)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detection.frequency.displayName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            confidenceBadge
        }
    }

    fileprivate var confidenceBadge: some View {
        let increasedContrast = colorSchemeContrast == .increased

        return Label(confidenceLabel, systemImage: confidenceIcon)
            .font(.caption2)
            .bold()
            .padding(.horizontal, SpacingTokens.xSmall)
            .padding(.vertical, SpacingTokens.xxSmall)
            .background(
                confidenceColor.opacity(increasedContrast ? 0.24 : 0.15)
            )
            .foregroundStyle(increasedContrast ? .primary : confidenceColor)
            .overlay {
                if increasedContrast {
                    Capsule()
                        .strokeBorder(confidenceColor, lineWidth: 1)
                }
            }
            .clipShape(.capsule)
    }

    fileprivate var detectionDetails: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    LabeledContent("Amount") {
                        Text(
                            detection.amount,
                            format: .currency(
                                code: detection.currencyCode.rawValue
                            )
                        )
                        .bold()
                    }
                    .font(TypographyTokens.caption)

                    if !detection.jurisdiction.isEmpty {
                        LabeledContent("Region") {
                            Text(
                                "\(String.flagEmoji(for: detection.jurisdiction)) \(detection.jurisdiction)"
                            )
                        }
                        .font(TypographyTokens.caption)
                    }

                    LabeledContent("Matches") {
                        Text("\(detection.matchedTransactionCount)")
                    }
                    .font(TypographyTokens.caption)
                }
            } else {
                HStack(spacing: SpacingTokens.medium) {
                    LabeledContent("Amount") {
                        Text(
                            detection.amount,
                            format: .currency(
                                code: detection.currencyCode.rawValue
                            )
                        )
                        .bold()
                    }
                    .font(TypographyTokens.caption)

                    if !detection.jurisdiction.isEmpty {
                        LabeledContent("Region") {
                            Text(
                                "\(String.flagEmoji(for: detection.jurisdiction)) \(detection.jurisdiction)"
                            )
                        }
                        .font(TypographyTokens.caption)
                    }

                    LabeledContent("Matches") {
                        Text("\(detection.matchedTransactionCount)")
                    }
                    .font(TypographyTokens.caption)
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    fileprivate var actionButtons: some View {
        HStack(spacing: SpacingTokens.small) {
            NomadFiActionButton(
                title: "Track",
                systemImage: "checkmark.circle",
                style: .primary,
                controlSize: .small,
                fillsWidth: false,
                accessibilityHint: "Confirms this detected subscription and starts tracking it.",
                action: onConfirm
            )

            NomadFiActionButton(
                title: "Dismiss",
                systemImage: "xmark.circle",
                style: .secondary,
                controlSize: .small,
                fillsWidth: false,
                accessibilityHint: "Dismisses this detected subscription suggestion.",
                action: onDismiss
            )
        }
    }
}

// MARK: - Helpers

extension DetectedSubscriptionCard {

    fileprivate var confidenceLabel: String {
        switch detection.confidence {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    fileprivate var confidenceColor: Color {
        switch detection.confidence {
        case .high: ColorTokens.positive
        case .medium: ColorTokens.warning
        case .low: ColorTokens.neutral
        }
    }

    fileprivate var confidenceIcon: String {
        switch detection.confidence {
        case .high: "checkmark.seal.fill"
        case .medium: "questionmark.circle.fill"
        case .low: "minus.circle.fill"
        }
    }

    fileprivate var accessibilityDescription: String {
        let amount = detection.amount.formatted(
            .currency(code: detection.currencyCode.rawValue)
        )
        return
            "Detected subscription: \(detection.merchantName), \(amount) \(detection.frequency.displayName), \(confidenceLabel) confidence. Double tap to track."
    }

}

#Preview {
    VStack(spacing: SpacingTokens.small) {
        DetectedSubscriptionCard(
            detection: SubscriptionDetector.DetectedSubscription(
                merchantName: "Netflix",
                amount: 15.49,
                currencyCode: .usd,
                frequency: .monthly,
                jurisdiction: "US",
                nextEstimatedDate: Calendar.current.date(
                    byAdding: .day,
                    value: 28,
                    to: .now
                ) ?? .now,
                matchedTransactionCount: 4,
                confidence: .high
            ),
            onConfirm: {},
            onDismiss: {}
        )

        DetectedSubscriptionCard(
            detection: SubscriptionDetector.DetectedSubscription(
                merchantName: "Spotify",
                amount: 11.99,
                currencyCode: .cad,
                frequency: .monthly,
                jurisdiction: "CA",
                nextEstimatedDate: Calendar.current.date(
                    byAdding: .day,
                    value: 14,
                    to: .now
                ) ?? .now,
                matchedTransactionCount: 2,
                confidence: .medium
            ),
            onConfirm: {},
            onDismiss: {}
        )
    }
    .padding()
}
