// DecisionDraftRow.swift
// NomadFi
//
// Compact row renderer for a single ``DecisionDraftRecord`` in the
// Decision Assistant's "Gathered intelligence" list. Visually
// distinct from ``DecisionHistoryRow`` (which shows analyzed
// decisions) so drafts never read as recommendations.
//
// Drafts v3 alignment: the row badge now reflects evaluator-derived
// *readiness* (engine ready / requires context / route to advanced
// tool / no engine yet / archived), not just the persisted
// `DecisionDraftStatus` lifecycle. The lifecycle stays unchanged —
// archived drafts always render as archived; active drafts render
// the more precise readiness label.

import SwiftUI

/// A single captured decision draft, rendered inline in the
/// Decision Assistant. Read-only — tapping the surrounding Button
/// presents the detail sheet; this row's job is display only.
struct DecisionDraftRow: View {

    let draft: DecisionDraftRecord

    /// Pre-derived readiness from
    /// `DecisionDraftRowReadiness.from(draft:accountSnapshot:)`.
    /// Required so the row stays purely presentational and so
    /// callers (the view + tests) make the readiness derivation
    /// explicit at the call site.
    let readiness: DecisionDraftRowReadiness

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

                DecisionDraftRowFooter(draft: draft, readiness: readiness)
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

    /// Composed from kind + title + readiness + last-updated date.
    /// Drafts v3: replaces the prior stale `draft.status` lookup
    /// for active drafts, which read every active draft as
    /// "Captured. Awaiting a deterministic engine — not yet
    /// analyzed." even when an engine handoff was already
    /// available.
    private var accessibilityDescription: String {
        let updated = draft.updatedAt.formatted(
            .dateTime.year().month(.wide).day()
        )
        return [
            draft.kind.accessibilityLabel,
            draft.displayTitle,
            readiness.accessibilityDescription,
            "Last updated \(updated)",
        ].joined(separator: ", ")
    }
}

// MARK: - Footer

private struct DecisionDraftRowFooter: View {

    let draft: DecisionDraftRecord
    let readiness: DecisionDraftRowReadiness

    var body: some View {
        HStack(spacing: SpacingTokens.xSmall) {
            StatusBadge(
                label: draft.kind.displayLabel,
                color: ColorTokens.neutral,
                systemImage: draft.kind.systemImage
            )

            StatusBadge(
                label: readiness.displayLabel,
                color: readinessColor(for: readiness),
                systemImage: readiness.systemImage
            )

            Spacer(minLength: 0)

            Text("Updated \(draft.updatedAt.formatted(.dateTime.year().month(.abbreviated).day()))")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    /// Colour mapping for the readiness badge. Kept in the view
    /// layer so the value-layer `DecisionDraftRowReadiness` stays
    /// free of SwiftUI imports.
    private func readinessColor(
        for readiness: DecisionDraftRowReadiness
    ) -> Color {
        switch readiness {
        case .archived: ColorTokens.neutral
        case .engineReady: ColorTokens.positive
        case .requiresContext: ColorTokens.warning
        case .routedToAdvancedTool: ColorTokens.brandPrimary
        case .noEngineYet: ColorTokens.neutral
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
        DecisionDraftRow(
            draft: preview,
            readiness: .engineReady
        )
    }
}
