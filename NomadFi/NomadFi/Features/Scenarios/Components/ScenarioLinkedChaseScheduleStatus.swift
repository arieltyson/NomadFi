// ScenarioLinkedChaseScheduleStatus.swift
// NomadFi
//
// Shows the current schedule state of the linked Chase card inside
// the Scenario brief. Users never edit dates here — if something
// needs fixing, a NavigationLink pushes the existing
// `CreditCardScheduleEditView` so the source of truth stays in
// Settings → Credit Card Calendar.

import SwiftUI

/// Status indicator + deep-link into the schedule editor for a linked
/// credit-card account.
struct ScenarioLinkedChaseScheduleStatus: View {

    let account: Account

    private var schedule: CreditCardSchedule {
        CreditCardSchedule(account: account)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(spacing: SpacingTokens.xSmall) {
                StatusBadge(
                    label: schedule.state.displayLabel,
                    color: Self.color(for: schedule.state),
                    systemImage: schedule.state.systemImage
                )

                if let closing = schedule.statementClosingDate {
                    Text("Closes \(closing.formatted(.dateTime.year().month(.abbreviated).day()))")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(for: schedule))

            if schedule.state != .confirmed {
                NavigationLink {
                    CreditCardScheduleEditView(account: account)
                } label: {
                    Label(
                        "Update in Settings → Credit Card Calendar",
                        systemImage: "arrow.up.right.square"
                    )
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.brandPrimary)
                }
                .accessibilityHint("Opens the statement calendar editor for this card.")
            }
        }
    }

    // MARK: - Semantic colour

    /// Mirrors `CreditCardScheduleRow.color(for:)` so Settings and the
    /// Scenario brief show the same colour for the same state.
    static func color(for state: CreditCardScheduleState) -> Color {
        switch state {
        case .missing: ColorTokens.neutral
        case .partial: ColorTokens.warning
        case .confirmed: ColorTokens.positive
        case .needsAttention: ColorTokens.negative
        }
    }

    // MARK: - VoiceOver

    static func accessibilityLabel(for schedule: CreditCardSchedule) -> String {
        var parts: [String] = ["Linked Chase schedule: \(schedule.state.displayLabel.lowercased())"]
        if let closing = schedule.statementClosingDate {
            parts.append("closes \(closing.formatted(.dateTime.year().month(.wide).day()))")
        }
        return parts.joined(separator: ", ")
    }
}
