// ReusableCheckCard.swift
// NomadFi
//
// IA/UI redesign — compact action card for the Decision Assistant's
// `Reusable checks` section. Reads as an evergreen tool the user
// can invoke any time, not as a piece of history. Visually
// distinct from `DecisionHistoryRow` (which is historical /
// resumable) and from `ScenarioPinnedCard` (which is scenario-
// specific).
//
// Design rationale (per Apple's HIG):
//   • Hierarchy — the card title carries the action affordance;
//     the subtitle stays one short line so the row scans quickly.
//   • Differentiation — a tinted icon badge plus a chevron right
//     reinforce the "tap to invoke" affordance without resorting
//     to traffic-light colours.
//   • Touch target — the entire card is the button.

import SwiftUI

/// Compact, button-shaped action card for one reusable check.
struct ReusableCheckCard: View {

    let identity: DecisionIdentity
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard {
                HStack(spacing: SpacingTokens.small) {
                    iconBadge

                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text(identity.title)
                            .font(TypographyTokens.body)
                            .bold()
                            .accessibilityAddTraits(.isHeader)
                            .lineLimit(2)
                        Text(identity.summary)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: SpacingTokens.xSmall)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the \(identity.title) brief. NomadFi runs this engine against your saved data and shows the rationale and sources.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    private var iconBadge: some View {
        TintedIconBadge(
            systemImage: identity.systemImage,
            tint: ColorTokens.brandPrimary
        )
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        // Mark this clearly as a reusable tool so VoiceOver users
        // hear the same semantic the visual treatment communicates.
        "Reusable check. \(identity.title). \(identity.summary)."
    }
}

#Preview {
    VStack(spacing: SpacingTokens.small) {
        ReusableCheckCard(
            identity: DecisionCatalog.purchaseCardCheck,
            action: {}
        )
        ReusableCheckCard(
            identity: DecisionCatalog.creditTimingCheck,
            action: {}
        )
    }
    .padding()
}
