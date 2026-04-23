// TaxEducationChecklistCard.swift
// NomadFi
//
// Static checklist card surfaced inside the Tax Vault education
// section. Read-only — no checkboxes, no persistence, no
// progress in this slice. Procedural prompts only.

import SwiftUI

struct TaxEducationChecklistCard: View {

    let checklist: TaxEducationChecklist

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(checklist.title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                ForEach(checklist.items) { item in
                    Label {
                        Text(item.text)
                            .font(TypographyTokens.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Text(checklist.escalationNote)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
