// NewDecisionScaffoldCard.swift
// NomadFi
//
// The "Gather intelligence" card in the Decision Assistant. Composes
// an honest intake header, a planned-channels list, and a primary
// "Capture decision" action that opens the on-device draft form.
// Drafts are stored locally and flagged as "needs engine" — this
// card never pretends NomadFi has analyzed them.

import SwiftUI

/// Intake scaffold for the Decision Assistant. Surfaces the
/// available (typed draft) and planned (Siri, Apple Intelligence)
/// channels, and exposes a single prominent button to capture a new
/// decision draft on-device.
struct NewDecisionScaffoldCard: View {

    /// Fires when the user taps the primary capture affordance. The
    /// parent view presents the ``DecisionDraftFormView`` sheet.
    let onCaptureTapped: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                NewDecisionScaffoldHeader()

                NewDecisionScaffoldIntakeList()

                Button(action: onCaptureTapped) {
                    Label("Capture decision", systemImage: "square.and.pencil")
                        .font(TypographyTokens.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Opens a local form to capture a new decision draft on this device.")

                Text("Saved drafts stay on-device and are marked needs engine until a deterministic NomadFi engine covers them. NomadFi does not auto-analyze drafts with generic AI.")
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

                Text("Capture a scenario now, in your own words. NomadFi keeps it on-device until a deterministic engine can analyze it.")
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
                systemImage: "square.and.pencil",
                title: "Typed scenario",
                subtitle: "Capture a decision draft right now. Stored on-device.",
                status: .available
            )
            NewDecisionIntakeRow(
                systemImage: "mic.circle.fill",
                title: "Siri & Shortcuts intake",
                subtitle: "Dictating new drafts is planned — today the voice path reviews saved decisions.",
                status: .planned
            )
            NewDecisionIntakeRow(
                systemImage: "apple.intelligence",
                title: "Apple Intelligence context",
                subtitle: "Optional on-device context when you grant access. Planned.",
                status: .planned
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

            badge
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
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
    NewDecisionScaffoldCard(onCaptureTapped: {})
        .padding()
}
