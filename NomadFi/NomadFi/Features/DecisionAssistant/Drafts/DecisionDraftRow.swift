// DecisionDraftRow.swift
// NomadFi
//
// Compact row renderer for a single ``DecisionDraftRecord`` in the
// Decision Assistant's "Gathered intelligence" list. Visually
// distinct from ``DecisionHistoryRow`` (which shows analyzed
// decisions) so drafts never read as recommendations.

import SwiftUI

/// A single captured decision draft, rendered inline in the
/// Decision Assistant. Read-only — tapping the surrounding Button
/// presents the detail sheet; this row's job is display only.
struct DecisionDraftRow: View {

    let draft: DecisionDraftRecord

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            kindIcon

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(draft.displayTitle)
                    .font(TypographyTokens.body)
                    .bold()
                    .lineLimit(2)

                if !draft.scenarioText.isEmpty {
                    Text(draft.scenarioText)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                DecisionDraftRowFooter(draft: draft)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    private var kindIcon: some View {
        Image(systemName: draft.kind.systemImage)
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .frame(width: 28, alignment: .center)
            .accessibilityHidden(true)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let updated = draft.updatedAt.formatted(
            .dateTime.year().month(.wide).day()
        )
        return [
            draft.kind.accessibilityLabel,
            draft.displayTitle,
            draft.status.accessibilityLabel,
            "Last updated \(updated)",
        ].joined(separator: ", ")
    }
}

// MARK: - Footer

private struct DecisionDraftRowFooter: View {

    let draft: DecisionDraftRecord

    var body: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            StatusBadge(
                label: draft.kind.displayLabel,
                color: ColorTokens.neutral,
                systemImage: draft.kind.systemImage
            )

            StatusBadge(
                label: draft.status.displayLabel,
                color: statusColor,
                systemImage: draft.status.systemImage
            )

            Spacer(minLength: 0)

            Text("Updated \(draft.updatedAt.formatted(.dateTime.year().month(.abbreviated).day()))")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private var statusColor: Color {
        switch draft.status {
        case .needsEngine: ColorTokens.warning
        case .archived: ColorTokens.neutral
        }
    }
}

#Preview {
    let preview = DecisionDraftRecord(
        title: "Summer laptop upgrade",
        scenarioText: "Buying a 14-inch MacBook for the U.S. internship. Trying to pick between Amazon.com with ACC and Wise USD.",
        kind: .purchase,
        merchantName: "Amazon",
        locationText: "San Francisco",
        amount: 1_899,
        currencyCode: .usd,
        timingText: "Before arrival",
        notes: "Need arrival timing aligned with Airbnb check-in."
    )

    return List {
        DecisionDraftRow(draft: preview)
    }
}
