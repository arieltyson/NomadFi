// DecisionDraftDetailView.swift
// NomadFi
//
// Read-only detail sheet for a saved ``DecisionDraftRecord``. Shows
// every field the user captured, flagged clearly as "Needs engine"
// so the sheet cannot be misread as a recommendation.
//
// Edit and archive flows are intentionally out of scope for this
// phase — the detail sheet exists so the user can re-read their own
// notes, not so NomadFi can start synthesising an answer.

import SwiftData
import SwiftUI

/// Read-only presentation of a single captured draft. Intentionally
/// verbose — every field the user entered is rendered, with absolute
/// timestamps, so the sheet doubles as the user's own audit trail.
struct DecisionDraftDetailView: View {

    let draft: DecisionDraftRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                    header

                    if !draft.scenarioText.isEmpty {
                        DraftDetailSection(title: "Scenario") {
                            Text(draft.scenarioText)
                                .font(TypographyTokens.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if hasContextFields {
                        DraftDetailSection(title: "Context") {
                            contextRows
                        }
                    }

                    if draft.amount != nil {
                        DraftDetailSection(title: "Amount") {
                            amountRow
                        }
                    }

                    if !draft.notes.isEmpty {
                        DraftDetailSection(title: "Notes") {
                            Text(draft.notes)
                                .font(TypographyTokens.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    timestamps

                    integrityNote
                }
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.medium)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Captured draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                Image(systemName: draft.kind.systemImage)
                    .font(.title)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(draft.displayTitle)
                        .font(TypographyTokens.sectionHeader)
                        .accessibilityAddTraits(.isHeader)

                    Text(draft.kind.displayLabel)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            StatusBadge(
                label: draft.status.displayLabel,
                color: ColorTokens.warning,
                systemImage: draft.status.systemImage
            )
            .accessibilityLabel(draft.status.accessibilityLabel)
        }
    }

    // MARK: - Context rows

    private var hasContextFields: Bool {
        !draft.merchantName.isEmpty
            || !draft.locationText.isEmpty
            || !draft.timingText.isEmpty
    }

    @ViewBuilder
    private var contextRows: some View {
        if !draft.merchantName.isEmpty {
            DraftDetailRow(label: "Merchant", value: draft.merchantName)
        }
        if !draft.locationText.isEmpty {
            DraftDetailRow(label: "Location", value: draft.locationText)
        }
        if !draft.timingText.isEmpty {
            DraftDetailRow(label: "Timing", value: draft.timingText)
        }
    }

    // MARK: - Amount

    private var amountRow: some View {
        let amount = draft.amount ?? 0
        let formatted = amount.formatted(
            .currency(code: draft.currencyCode.rawValue)
        )
        return DraftDetailRow(label: "Amount", value: formatted)
    }

    // MARK: - Timestamps

    private var timestamps: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            DraftDetailRow(
                label: "Captured",
                value: draft.createdAt.formatted(
                    .dateTime.year().month(.wide).day().hour().minute()
                )
            )
            DraftDetailRow(
                label: "Last updated",
                value: draft.updatedAt.formatted(
                    .dateTime.year().month(.wide).day().hour().minute()
                )
            )
        }
    }

    // MARK: - Integrity note

    private var integrityNote: some View {
        GlassCard {
            Label {
                Text("NomadFi stored this draft on-device only. A deterministic engine for this kind of decision hasn't shipped yet — until one does, NomadFi will not generate a recommendation from this capture.")
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
}

// MARK: - Detail helpers

private struct DraftDetailSection<Content: View>: View {

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text(title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    content
                }
            }
        }
    }
}

private struct DraftDetailRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: SpacingTokens.small)
            Text(value)
                .font(TypographyTokens.body)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    let draft = DecisionDraftRecord(
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
    DecisionDraftDetailView(draft: draft)
}
