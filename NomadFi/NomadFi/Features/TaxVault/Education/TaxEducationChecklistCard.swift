// TaxEducationChecklistCard.swift
// NomadFi
//
// Interactive checklist card. Each row is a toggle — tapping
// flips the item between completed and not-started via
// `TaxEducationProgressService`. Read-state is derived from the
// persisted `TaxEducationProgressRecord`s the parent view passes
// in via `isCompleted`. No progress bar, no streaks — just a
// calm, scannable review surface.

import SwiftUI

struct TaxEducationChecklistCard: View {

    let checklist: TaxEducationChecklist

    /// Resolves the current completion state for an item. Kept as
    /// a closure so the parent owns the record query.
    let isCompleted: (TaxEducationChecklistItem) -> Bool

    /// Called when the user taps a row. The parent forwards this
    /// to `TaxEducationViewModel.toggleChecklistItem(...)`.
    let onToggle: (TaxEducationChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(checklist.title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                ForEach(checklist.items) { item in
                    row(for: item)
                }
            }

            Text(checklist.escalationNote)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(for item: TaxEducationChecklistItem) -> some View {
        let completed = isCompleted(item)
        return Button {
            onToggle(item)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(completed ? ColorTokens.positive : ColorTokens.brandPrimary)
                    .font(.title3)
                    .frame(width: 26, alignment: .center)
                    .accessibilityHidden(true)

                Text(item.text)
                    .font(TypographyTokens.body)
                    .foregroundStyle(completed ? .secondary : .primary)
                    .strikethrough(completed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: item, completed: completed))
        .accessibilityHint(completed ? "Marks this item not reviewed yet." : "Marks this item reviewed.")
        .accessibilityAddTraits(completed ? .isSelected : [])
    }

    private func accessibilityLabel(
        for item: TaxEducationChecklistItem,
        completed: Bool
    ) -> String {
        if completed {
            return "Reviewed. \(item.text)"
        }
        return "Next to review. \(item.text)"
    }
}
