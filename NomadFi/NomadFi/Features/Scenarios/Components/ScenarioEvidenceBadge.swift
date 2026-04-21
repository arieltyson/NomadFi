// ScenarioEvidenceBadge.swift
// NomadFi
//
// Thin wrapper around `StatusBadge` that renders a `ScenarioEvidenceTag`
// with a consistent color, SF Symbol, and short label. Kept as its own
// file so the same badge is reused across the dashboard card, the
// payment-option rows, and the cost breakdown.

import SwiftUI

/// A compact evidence label used on the Scenario Decision Brief.
struct ScenarioEvidenceBadge: View {

    let tag: ScenarioEvidenceTag

    var body: some View {
        StatusBadge(
            label: tag.displayLabel,
            color: color,
            systemImage: tag.systemImage
        )
        .accessibilityLabel("Evidence: \(tag.displayLabel)")
    }

    private var color: Color {
        switch tag {
        case .screenshotFact: ColorTokens.neutral
        case .officialSource: ColorTokens.positive
        case .needsUserInput: ColorTokens.warning
        case .inference: ColorTokens.brandPrimary
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: SpacingTokens.small) {
        ForEach(ScenarioEvidenceTag.allCases, id: \.self) { tag in
            ScenarioEvidenceBadge(tag: tag)
        }
    }
    .padding()
}
