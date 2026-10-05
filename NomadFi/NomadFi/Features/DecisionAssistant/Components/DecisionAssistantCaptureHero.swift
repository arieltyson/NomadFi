// DecisionAssistantCaptureHero.swift
// NomadFi
//
// IA/UI redesign — the Decisions tab's primary command module.
// `Capture decision` is the dominant first-viewport action; the
// supporting Siri and Apple Intelligence rows live underneath the
// CTA so they read as alternate intake paths rather than peer
// affordances competing for the same focal point.
//
// Design rationale (per Apple's HIG):
//   • Hierarchy + harmony — one prominent CTA per command module,
//     surrounded by quieter supporting rows.
//   • Consistent material — uses the existing `SurfaceCard`
//     treatment that the rest of the Decisions tab already relies
//     on, so the redesign feels native rather than novel.
//   • Inclusivity — large hit target, dynamic-type friendly,
//     VoiceOver labels separate the CTA from the supporting rows.
//   • Trust line below the CTA preserves the no-auto-analysis
//     contract surfaced by Drafts v2 / v3 / Phase 9A.

import SwiftUI

/// Primary command module for the Decisions tab. Hero CTA +
/// supporting intake rows (Siri / Shortcuts, Apple Intelligence).
struct DecisionAssistantCaptureHero: View {

    /// Fires when the user taps the primary capture affordance.
    /// The parent presents `DecisionDraftFormView`.
    let onCaptureTapped: () -> Void

    /// Fires when the user taps the Apple Intelligence row. The
    /// parent presents `DecisionAIIntakeSheet`. The hero never
    /// presents the sheet itself so the parent stays the single
    /// owner of sheet state.
    let onAppleIntelligenceTapped: () -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                eyebrow
                ctaButton
                supportingRowsDivider
                supportingRows
                trustLine
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Start a decision")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Text("Capture a scenario in your own words. NomadFi keeps it on this device and shows you what it can do with it.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Primary CTA

    private var ctaButton: some View {
        // Routed through `NomadFiActionButton` so the
        // `square.and.pencil` glyph renders next to the title at
        // every control size + Dynamic Type level — no
        // press-only icon flash.
        NomadFiActionButton(
            title: "Capture decision",
            systemImage: "square.and.pencil",
            style: .primary,
            controlSize: .large,
            accessibilityHint: "Opens a local form to capture a new decision draft on this device. NomadFi will not analyze it automatically.",
            action: onCaptureTapped
        )
    }

    // MARK: - Supporting rows

    private var supportingRowsDivider: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            Rectangle()
                .fill(ColorTokens.neutral.opacity(0.2))
                .frame(height: 0.5)
            Text("Or another way")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(ColorTokens.neutral.opacity(0.2))
                .frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var supportingRows: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            DecisionIntakeSupportingRow(
                systemImage: "mic.circle.fill",
                title: "Siri & Shortcuts",
                subtitle: "Say “Capture a decision in NomadFi” and dictate the scenario.",
                action: nil
            )
            DecisionIntakeSupportingRow(
                systemImage: "apple.intelligence",
                title: "Apple Intelligence",
                subtitle: "On-device structuring. NomadFi extracts draft fields; you review and confirm before save.",
                action: onAppleIntelligenceTapped
            )
        }
    }

    // MARK: - Trust line

    private var trustLine: some View {
        Label {
            Text("Drafts stay on this device. NomadFi never analyzes them automatically — you decide when to hand a draft to a deterministic engine.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Supporting intake row

/// Compact row used inside the capture hero for alternate intake
/// channels. Renders as a `Button` when an action is supplied so
/// VoiceOver and pointer hit-testing stay correct.
private struct DecisionIntakeSupportingRow: View {

    let systemImage: String
    let title: String
    let subtitle: String
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
        }
        .padding(.vertical, SpacingTokens.xxSmall)
    }
}

#Preview {
    DecisionAssistantCaptureHero(
        onCaptureTapped: {},
        onAppleIntelligenceTapped: {}
    )
    .padding()
}
