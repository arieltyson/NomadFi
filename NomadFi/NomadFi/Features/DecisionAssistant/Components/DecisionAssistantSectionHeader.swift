// DecisionAssistantSectionHeader.swift
// NomadFi
//
// Shared section-header treatment for the Decision Assistant. Extracted
// from `DecisionAssistantView` so the IA/UI redesign reuses one
// header style across every section without re-declaring it inline.
// Per Apple's HIG layout guidance: clear hierarchy, consistent
// section semantics, and accessibility headers that VoiceOver can
// rotor through.

import SwiftUI

/// Section header used by every Decisions-tab section. Title +
/// subtitle, left-aligned, with the title carrying the
/// `.isHeader` accessibility trait so VoiceOver users can navigate
/// by section.
struct DecisionAssistantSectionHeader: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
