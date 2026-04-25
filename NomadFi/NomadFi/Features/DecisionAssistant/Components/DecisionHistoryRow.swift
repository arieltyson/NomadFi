// DecisionHistoryRow.swift
// NomadFi
//
// Compact row for the Previous Decisions section of the Decision
// Assistant. Uses list-native layout rather than nesting another
// GlassCard so we never end up with cards-inside-cards.
//
// History semantics hardening: this row only renders for
// decisions that have already been reviewed (filtered upstream
// by `DecisionReviewEvidence`). The "Not started" branch was
// removed because untouched decisions no longer reach the
// "Previous decisions" surface — they live in `Now` until the
// user reviews them at least once.

import SwiftUI

/// A single row in the Decision Assistant's history list. Always
/// represents a decision the user has reviewed at least once.
struct DecisionHistoryRow: View {

    let identity: DecisionIdentity
    let ruling: String

    /// When the per-engine record (or `DecisionReviewMarker`) was
    /// last touched. May be `nil` for engines whose review evidence
    /// is purely a flag — in that case the row omits the timestamp
    /// instead of guessing one.
    let lastUpdatedAt: Date?

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

                statusBadge
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let lastUpdatedAt {
            StatusBadge(
                label: "Last reviewed \(lastUpdatedAt.formatted(.dateTime.year().month(.abbreviated).day()))",
                color: ColorTokens.positive,
                systemImage: "clock.fill"
            )
        } else {
            StatusBadge(
                label: "Reviewed",
                color: ColorTokens.positive,
                systemImage: "checkmark.circle.fill"
            )
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = [identity.title, ruling]
        if let lastUpdatedAt {
            let formatted = lastUpdatedAt.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("last reviewed \(formatted)")
        } else {
            parts.append("reviewed")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        DecisionHistoryRow(
            identity: DecisionCatalog.amazonArrivalOrder,
            ruling: "Pay in USD. Use Chase only if utilization is controlled.",
            lastUpdatedAt: Date(timeIntervalSince1970: 1_734_000_000)
        )
        DecisionHistoryRow(
            identity: DecisionCatalog.creditTimingCheck,
            ruling: "All cards look ready.",
            lastUpdatedAt: nil
        )
    }
}
