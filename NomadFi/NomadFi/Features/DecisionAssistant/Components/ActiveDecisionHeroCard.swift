// ActiveDecisionHeroCard.swift
// NomadFi
//
// The Decision Assistant's primary surface: a single, premium
// GlassCard previewing the currently-active decision. Designed to
// feel like a high-signal command center — ruling, evidence badges,
// last-updated timestamp, and a single CTA to open the full brief.

import SwiftUI

/// Premium glass card for the Decision Assistant's active decision.
/// Tapping the card opens the full ``ScenarioDecisionBriefView``.
struct ActiveDecisionHeroCard: View {

    let identity: DecisionIdentity
    let ruling: String
    let lastUpdatedAt: Date?
    let outstandingCheckCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    ActiveDecisionHeroHeader(identity: identity)

                    ActiveDecisionHeroRuling(ruling: ruling)

                    ActiveDecisionHeroEvidence()

                    ActiveDecisionHeroFooter(
                        lastUpdatedAt: lastUpdatedAt,
                        outstandingCheckCount: outstandingCheckCount
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens the full decision brief with cost breakdown, payment options, and user checks.")
    }

    private var accessibilityDescription: String {
        var parts = ["Active decision: \(identity.title)", ruling]
        if outstandingCheckCount > 0 {
            parts.append("\(outstandingCheckCount) user checks remaining")
        }
        if let lastUpdatedAt {
            let formatted = lastUpdatedAt.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("last updated \(formatted)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Header

private struct ActiveDecisionHeroHeader: View {

    let identity: DecisionIdentity

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: identity.systemImage)
                .font(.title2)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Active decision")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                Text(identity.title)
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: SpacingTokens.xSmall)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Ruling

private struct ActiveDecisionHeroRuling: View {

    let ruling: String

    var body: some View {
        Text(ruling)
            .font(TypographyTokens.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Evidence row

private struct ActiveDecisionHeroEvidence: View {

    var body: some View {
        HStack(spacing: SpacingTokens.xxSmall) {
            ScenarioEvidenceBadge(tag: .screenshotFact)
            ScenarioEvidenceBadge(tag: .officialSource)
            ScenarioEvidenceBadge(tag: .needsUserInput)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Footer

private struct ActiveDecisionHeroFooter: View {

    let lastUpdatedAt: Date?
    let outstandingCheckCount: Int

    var body: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            if outstandingCheckCount > 0 {
                StatusBadge(
                    label: "\(outstandingCheckCount) check\(outstandingCheckCount == 1 ? "" : "s")",
                    color: ColorTokens.warning,
                    systemImage: "questionmark.circle.fill"
                )
            } else {
                StatusBadge(
                    label: "Ready",
                    color: ColorTokens.positive,
                    systemImage: "checkmark.seal.fill"
                )
            }

            Spacer(minLength: 0)

            if let lastUpdatedAt {
                Text("As of \(lastUpdatedAt.formatted(.dateTime.year().month(.abbreviated).day()))")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    ActiveDecisionHeroCard(
        identity: DecisionCatalog.amazonArrivalOrder,
        ruling: "Pay in USD. Use Chase only if utilization is controlled; otherwise use Wise USD.",
        lastUpdatedAt: Date(timeIntervalSince1970: 1_734_000_000),
        outstandingCheckCount: 3,
        action: {}
    )
    .padding()
}
