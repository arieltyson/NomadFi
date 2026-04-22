// NewDecisionScaffoldCard.swift
// NomadFi
//
// Honest scaffolding for future decision intake — typed scenarios,
// Siri / App Intents, optional Apple Intelligence context. This card
// deliberately does *not* run a generic LLM, does *not* fabricate
// analysis, and does *not* advertise capability NomadFi has not
// actually shipped. It exists to reserve the visual space and tell
// the user what's coming, not to pretend it's already here.

import SwiftUI

/// The "Gather Intelligence" / "New Decision" card shown beneath the
/// Decision Assistant's history list. Static today — interactive
/// intake lands when an App Intent and a second deterministic engine
/// are wired up.
struct NewDecisionScaffoldCard: View {

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                NewDecisionScaffoldHeader()

                NewDecisionScaffoldIntakeList()

                Text("Today, NomadFi's actionable recommendations come from its own deterministic, source-backed engine — not from a generic language model. New intake channels will route into that engine as they ship.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gather intelligence for a new decision. Coming soon: typed scenarios, Siri shortcuts, and optional Apple Intelligence context. Today's recommendations come from NomadFi's deterministic source-backed engine.")
    }
}

// MARK: - Header

private struct NewDecisionScaffoldHeader: View {

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Gather intelligence")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Text("Describe a purchase in your own words — routed into NomadFi's deterministic engine.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Intake list

private struct NewDecisionScaffoldIntakeList: View {

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            NewDecisionIntakeRow(
                systemImage: "keyboard",
                title: "Typed scenario",
                subtitle: "Describe a purchase, location, and timing. Planned."
            )
            NewDecisionIntakeRow(
                systemImage: "mic.circle.fill",
                title: "Siri & Shortcuts",
                subtitle: "Ask “Which card should I use?” in context. Planned."
            )
            NewDecisionIntakeRow(
                systemImage: "apple.intelligence",
                title: "Apple Intelligence context",
                subtitle: "Optional on-device context when you grant access. Planned."
            )
        }
    }
}

private struct NewDecisionIntakeRow: View {

    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypographyTokens.body)
                Text(subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            StatusBadge(
                label: "Planned",
                color: ColorTokens.neutral,
                systemImage: "hourglass"
            )
        }
    }
}

#Preview {
    NewDecisionScaffoldCard()
        .padding()
}
