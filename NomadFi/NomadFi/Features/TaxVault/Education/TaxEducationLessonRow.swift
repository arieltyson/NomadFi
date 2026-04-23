// TaxEducationLessonRow.swift
// NomadFi
//
// Compact row renderer for a single lesson inside the Tax Vault
// education section. Read-only and calm — tapping opens the full
// detail sheet via the parent view-model.

import SwiftUI

struct TaxEducationLessonRow: View {

    let lesson: TaxEducationLesson

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: "book.closed")
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(lesson.title)
                    .font(TypographyTokens.body)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)
                Text(lesson.whatItIs)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SpacingTokens.xSmall)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SpacingTokens.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lesson.region.displayName) lesson. \(lesson.title). Education only.")
    }
}
