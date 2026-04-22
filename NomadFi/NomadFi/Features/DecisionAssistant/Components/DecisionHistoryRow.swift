// DecisionHistoryRow.swift
// NomadFi
//
// Compact row for the Previous Decisions section of the Decision
// Assistant. Uses list-native layout rather than nesting another
// GlassCard so we never end up with cards-inside-cards.

import SwiftUI

/// A single row in the Decision Assistant's history list.
struct DecisionHistoryRow: View {

    let identity: DecisionIdentity
    let ruling: String
    let lastUpdatedAt: Date?
    let isInteracted: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: identity.systemImage)
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(identity.title)
                    .font(TypographyTokens.body)
                    .bold()

                Text(ruling)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                DecisionHistoryRowStatus(
                    lastUpdatedAt: lastUpdatedAt,
                    isInteracted: isInteracted
                )
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [identity.title, ruling]
        if isInteracted, let lastUpdatedAt {
            let formatted = lastUpdatedAt.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("last updated \(formatted)")
        } else {
            parts.append("no inputs saved yet")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Status badge

private struct DecisionHistoryRowStatus: View {

    let lastUpdatedAt: Date?
    let isInteracted: Bool

    var body: some View {
        if isInteracted, let lastUpdatedAt {
            StatusBadge(
                label: "Saved \(lastUpdatedAt.formatted(.dateTime.year().month(.abbreviated).day()))",
                color: ColorTokens.positive,
                systemImage: "clock.fill"
            )
        } else {
            StatusBadge(
                label: "Not started",
                color: ColorTokens.neutral,
                systemImage: "circle.dashed"
            )
        }
    }
}

#Preview {
    List {
        DecisionHistoryRow(
            identity: DecisionCatalog.amazonArrivalOrder,
            ruling: "Pay in USD. Use Chase only if utilization is controlled.",
            lastUpdatedAt: Date(timeIntervalSince1970: 1_734_000_000),
            isInteracted: true
        )
        DecisionHistoryRow(
            identity: DecisionCatalog.amazonArrivalOrder,
            ruling: "Pay in USD. Use Chase only if utilization is controlled.",
            lastUpdatedAt: nil,
            isInteracted: false
        )
    }
}
