// NewDecisionScaffoldCard.swift
// NomadFi
//
// The "Gather intelligence" card in the Decision Assistant.
// Composes an honest intake header, the available intake channels,
// and a primary "Capture decision" action that opens the on-device
// draft form. Drafts are stored locally; readiness is surfaced
// inline in the list. NomadFi never auto-analyzes drafts.
//
// Phase 9A: the Apple Intelligence row is now a tappable entry
// into `DecisionAIIntakeSheet` — on-device structured intake that
// still requires explicit user confirmation before save.

import SwiftUI

/// Intake scaffold for the Decision Assistant.
struct NewDecisionScaffoldCard: View {

    /// Fires when the user taps the primary capture affordance.
    /// The parent view presents `DecisionDraftFormView`.
    let onCaptureTapped: () -> Void

    /// Fires when the user taps the Apple Intelligence row. The
    /// parent view presents `DecisionAIIntakeSheet`.
    let onAppleIntelligenceTapped: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                NewDecisionScaffoldHeader()

                NewDecisionScaffoldIntakeList(
                    onAppleIntelligenceTapped: onAppleIntelligenceTapped
                )

                Button(action: onCaptureTapped) {
                    Label("Capture decision", systemImage: "square.and.pencil")
                        .font(TypographyTokens.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Opens a local form to capture a new decision draft on this device.")

                Text("Drafts stay on this device. NomadFi shows what it can do with each one — open Purchase Card Check, open Credit Timing, or point at Tax Vault / Investing Learn — without auto-analyzing anything.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
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

                Text("Capture a scenario in your own words. NomadFi keeps it on-device and shows you what it can do with it.")
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

    let onAppleIntelligenceTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            NewDecisionIntakeRow(
                systemImage: "square.and.pencil",
                title: "Typed scenario",
                subtitle: "Capture a decision draft right now. Stored on-device.",
                status: .available,
                action: nil
            )
            NewDecisionIntakeRow(
                systemImage: "mic.circle.fill",
                title: "Siri & Shortcuts intake",
                subtitle: "Say “Capture a decision in NomadFi” and dictate the scenario. Stored on-device as a draft.",
                status: .available,
                action: nil
            )
            NewDecisionIntakeRow(
                systemImage: "apple.intelligence",
                title: "Apple Intelligence context",
                subtitle: "On-device structuring. NomadFi extracts draft fields from a natural-language scenario; you review and confirm before save.",
                status: .available,
                action: onAppleIntelligenceTapped
            )
        }
    }
}

private struct NewDecisionIntakeRow: View {

    enum Status {
        case available
        case planned
    }

    let systemImage: String
    let title: String
    let subtitle: String
    let status: Status
    /// Optional tap handler. When non-nil, the row renders as a
    /// `Button` so the affordance is reachable via tap and via
    /// VoiceOver. When nil, the row renders as a static label.
    let action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle)")
            .accessibilityAddTraits(.isButton)
        } else {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title). \(subtitle)")
        }
    }

    private var rowContent: some View {
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

            badge
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .available:
            StatusBadge(
                label: "Available",
                color: ColorTokens.positive,
                systemImage: "checkmark.circle"
            )
        case .planned:
            StatusBadge(
                label: "Planned",
                color: ColorTokens.neutral,
                systemImage: "hourglass"
            )
        }
    }
}

#Preview {
    NewDecisionScaffoldCard(
        onCaptureTapped: {},
        onAppleIntelligenceTapped: {}
    )
    .padding()
}
