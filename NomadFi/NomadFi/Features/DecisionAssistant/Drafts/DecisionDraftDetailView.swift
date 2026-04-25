// DecisionDraftDetailView.swift
// NomadFi
//
// Detail sheet for a saved ``DecisionDraftRecord``. Shows every field
// the user captured, flagged clearly as "Needs engine" (or
// "Archived") so the sheet cannot be misread as a recommendation.
//
// Lifecycle actions live here rather than on the row:
//
//   - **Edit** is a primary toolbar button that hands the request
//     back to the parent (via `onRequestEdit`). The parent dismisses
//     this detail sheet and presents the edit form, so we never end
//     up with a sheet-inside-a-sheet. Apple's sheet guidance is
//     clear: one modal at a time.
//   - **Archive / Restore** are reversible, so they run inline
//     without a confirmation (HIG alert guidance: don't interrupt
//     for reversible actions).
//   - **Delete** is irreversible. It uses an `.alert` (not a
//     confirmation dialog) so the prompt presents as a centered
//     modal on every size class — including the anchored-popover
//     behaviour `.confirmationDialog` produces on iPad — and per
//     Apple HIG: alerts are the right control for destructive
//     operations that risk irretrievable data loss. The Delete
//     button carries the explicit destructive role; once
//     confirmed, the parent removes the record and the sheet
//     dismisses cleanly.

import SwiftData
import SwiftUI

/// Read-only presentation of a single captured draft, with a
/// lifecycle toolbar (Edit, Archive/Restore, Delete). Intentionally
/// verbose — every field the user entered is rendered, with absolute
/// timestamps, so the sheet doubles as the user's own audit trail.
struct DecisionDraftDetailView: View {

    let draft: DecisionDraftRecord

    /// Invoked when the user taps Edit. The parent should dismiss
    /// this detail sheet and present ``DecisionDraftFormView`` in
    /// edit mode to avoid nested sheets.
    let onRequestEdit: (DecisionDraftRecord) -> Void

    /// Invoked when the user confirms permanent deletion. The parent
    /// is responsible for the SwiftData delete and for dismissing
    /// this sheet so the now-dangling reference is released.
    let onRequestDelete: (DecisionDraftRecord) -> Void

    /// Phase 1 follow-through — invoked when the user taps a
    /// handoff action ("Open purchase check" / "Open credit timing
    /// check"). The parent dismisses this sheet and routes through
    /// the existing engine surface. `nil` is allowed so previews and
    /// tests can render the view without a router.
    var onRequestHandoff: ((DecisionDraftRecord, DecisionDraftNextAction) -> Void)? = nil

    /// Phase 1 follow-through — pure account snapshot the evaluator
    /// uses for credit-timing draft readiness. Defaults to empty so
    /// previews and tests can render the view without a query.
    var accountSnapshot: DecisionDraftAccountSnapshot = .empty

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isDeleteConfirmationPresented = false

    private var evaluation: DecisionDraftEvaluation {
        DecisionDraftEvaluator.evaluate(
            draft,
            accountSnapshot: accountSnapshot
        )
    }

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

                    nextStepSection

                    timestamps

                    integrityNote
                }
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.medium)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Captured draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert(
                "Delete this draft from this device?",
                isPresented: $isDeleteConfirmationPresented
            ) {
                Button("Delete draft", role: .destructive) {
                    onRequestDelete(draft)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("NomadFi stores this draft only on this iPhone. Deleting removes the captured text, kind, and any amount you entered. This cannot be undone.")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                onRequestEdit(draft)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .accessibilityLabel("Edit draft")
            .accessibilityHint("Opens the draft in the edit form.")
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                archiveOrRestoreButton

                Divider()

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete draft…", systemImage: "trash")
                }
            } label: {
                Label("More actions", systemImage: "ellipsis.circle")
            }
            .accessibilityLabel("More draft actions")
        }
    }

    @ViewBuilder
    private var archiveOrRestoreButton: some View {
        switch draft.status {
        case .needsEngine:
            Button {
                DecisionDraftStore.archive(draft, in: modelContext)
            } label: {
                Label("Archive draft", systemImage: "archivebox")
            }
            .accessibilityHint("Hides the draft from the main list. You can restore it later.")
        case .archived:
            Button {
                DecisionDraftStore.restore(draft, in: modelContext)
            } label: {
                Label("Restore draft", systemImage: "tray.and.arrow.up")
            }
            .accessibilityHint("Moves the draft back to the Gathered intelligence list.")
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
                color: statusColor,
                systemImage: draft.status.systemImage
            )
            .accessibilityLabel(draft.status.accessibilityLabel)
        }
    }

    private var statusColor: Color {
        switch draft.status {
        case .needsEngine: ColorTokens.warning
        case .archived: ColorTokens.neutral
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

    // MARK: - Next step (Phase 1 follow-through)

    @ViewBuilder
    private var nextStepSection: some View {
        if evaluation.hasContent {
            DraftDetailSection(title: "What NomadFi can do now") {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    Text(evaluation.headline)
                        .font(TypographyTokens.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if !evaluation.nextActions.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                            ForEach(evaluation.nextActions) { action in
                                actionRow(for: action)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(for action: DecisionDraftNextAction) -> some View {
        if action.isHandoff {
            NomadFiActionButton(
                title: action.displayLabel,
                systemImage: action.systemImage,
                style: .primary,
                accessibilityHint: action.accessibilityHint,
                action: { onRequestHandoff?(draft, action) }
            )
        } else {
            Label {
                Text(action.displayLabel)
                    .font(TypographyTokens.body)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: action.systemImage)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(action.accessibilityHint)
        }
    }

    // MARK: - Integrity note

    private var integrityNote: some View {
        GlassCard {
            Label {
                Text("NomadFi stored this draft on-device only. Drafts are never auto-analyzed; NomadFi only opens an existing deterministic engine when you tap a handoff button above.")
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
    DecisionDraftDetailView(
        draft: draft,
        onRequestEdit: { _ in },
        onRequestDelete: { _ in }
    )
    .modelContainer(for: [DecisionDraftRecord.self], inMemory: true)
}
