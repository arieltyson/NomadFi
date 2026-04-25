// ScenarioPinnedCard.swift
// NomadFi
//
// IA/UI redesign — distinct treatment for a scenario-specific
// pinned decision (Amazon arrival order today). Reads as a
// situational decision the user is tracking rather than a tool
// they invoke on demand. Visually different from
// `ReusableCheckCard` so the two never look interchangeable.
//
// Design rationale (per Apple's HIG):
//   • Differentiation — explicit "Pinned scenario" eyebrow plus a
//     ruling preview makes this card read as ongoing context.
//   • Hierarchy — keeps the ruling sentence (the substantive
//     value) above the action chevron.
//   • Status disclosure — `outstandingCheckCount` chip surfaces
//     pending user input without resorting to colour alone.

import SwiftUI

/// Distinct, less-shouty card for a pinned scenario-specific
/// decision. Tapping the card opens the matching brief sheet.
struct ScenarioPinnedCard: View {

    let identity: DecisionIdentity
    let ruling: String
    let lastUpdatedAt: Date?
    let outstandingCheckCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    eyebrow
                    rulingPreview
                    footer
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the pinned scenario's full brief.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    private var eyebrow: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("Pinned scenario")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    private var rulingPreview: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Image(systemName: identity.systemImage)
                    .font(.title3)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
                Text(identity.title)
                    .font(TypographyTokens.body)
                    .bold()
                    .accessibilityAddTraits(.isHeader)
            }

            Text(ruling)
                .font(TypographyTokens.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            statusChip

            Spacer(minLength: 0)

            if let lastUpdatedAt {
                Text("As of \(lastUpdatedAt.formatted(.dateTime.year().month(.abbreviated).day()))")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        if outstandingCheckCount > 0 {
            StatusBadge(
                label: "\(outstandingCheckCount) check\(outstandingCheckCount == 1 ? "" : "s")",
                color: ColorTokens.warning,
                systemImage: "questionmark.circle.fill"
            )
        } else {
            StatusBadge(
                label: "Ready to review",
                color: ColorTokens.positive,
                systemImage: "checkmark.seal.fill"
            )
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = [
            "Pinned scenario.",
            identity.title,
            ruling,
        ]
        if outstandingCheckCount > 0 {
            parts.append("\(outstandingCheckCount) user check\(outstandingCheckCount == 1 ? "" : "s") remaining.")
        }
        if let lastUpdatedAt {
            let formatted = lastUpdatedAt.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("Last updated \(formatted).")
        }
        return parts.joined(separator: " ")
    }
}

#Preview {
    ScenarioPinnedCard(
        identity: DecisionCatalog.amazonArrivalOrder,
        ruling: "Pay in USD. Use Chase only if utilization is controlled; otherwise use Wise USD.",
        lastUpdatedAt: Date(timeIntervalSince1970: 1_734_000_000),
        outstandingCheckCount: 3,
        action: {}
    )
    .padding()
}
