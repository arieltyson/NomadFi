// InvestingEducationChecklistCard.swift
// NomadFi
//
// Interactive checklist card for the Investing Learn surface. Each
// row is a tap target that flips the item between completed and
// not-started via `InvestingEducationProgressService`. Read state
// is derived from the persisted `InvestingEducationProgressRecord`s
// the parent passes in via `isCompleted`. Mirrors the tax stack's
// checklist card so the two surfaces feel uniform.

import SwiftUI

struct InvestingEducationChecklistCard: View {

    let checklist: InvestingEducationChecklist

    let isCompleted: (InvestingEducationChecklistItem) -> Bool

    let onToggle: (InvestingEducationChecklistItem) -> Void

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

    private func row(for item: InvestingEducationChecklistItem) -> some View {
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
        for item: InvestingEducationChecklistItem,
        completed: Bool
    ) -> String {
        if completed {
            return "Reviewed. \(item.text)"
        }
        return "Next to review. \(item.text)"
    }
}
