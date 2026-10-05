// ScenarioDashboardCard.swift
// NomadFi
//
// Dashboard entry point into Scenario 1. A single SurfaceCard that
// previews the ruling and opens the full Scenario Decision Brief.

import SwiftUI

/// The Amazon arrival-order card rendered above the Dashboard's
/// "Your Money This Week" section.
struct ScenarioDashboardCard: View {

    let ruling: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    HStack(spacing: SpacingTokens.xSmall) {
                        Image(systemName: "cart.fill.badge.plus")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)

                        Text("Amazon arrival order")
                            .font(TypographyTokens.sectionHeader)
                            .accessibilityAddTraits(.isHeader)

                        Spacer(minLength: SpacingTokens.xSmall)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }

                    Text(ruling)
                        .font(TypographyTokens.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: SpacingTokens.xxSmall) {
                        ScenarioEvidenceBadge(tag: .screenshotFact)
                        ScenarioEvidenceBadge(tag: .needsUserInput)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amazon arrival order decision brief. \(ruling)")
        .accessibilityHint("Opens the full decision brief with cost breakdown, payment options, and user checks.")
    }
}

#Preview {
    ScenarioDashboardCard(
        ruling: "Pay in USD. Use Chase only if utilization is controlled; otherwise use Wise USD.",
        action: {}
    )
    .padding()
}
