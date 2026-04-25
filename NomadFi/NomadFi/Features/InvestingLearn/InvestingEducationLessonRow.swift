// InvestingEducationLessonRow.swift
// NomadFi
//
// Compact row renderer for a single investing-education lesson
// inside the Investing Learn surface. Mirrors the visual shape of
// `TaxEducationLessonRow` so the two stacks read uniformly. Tapping
// opens the detail sheet.

import SwiftUI

struct InvestingEducationLessonRow: View {

    let lesson: InvestingEducationLesson

    /// `true` when the user has explicitly marked the lesson
    /// reviewed. Derived from persisted progress records upstream.
    let isReviewed: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: isReviewed ? "checkmark.seal.fill" : "book.closed")
                .foregroundStyle(isReviewed ? ColorTokens.positive : ColorTokens.brandPrimary)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Text(lesson.title)
                        .font(TypographyTokens.body)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)
                    if isReviewed {
                        StatusBadge(
                            label: "Reviewed",
                            color: ColorTokens.positive,
                            systemImage: "checkmark"
                        )
                        .accessibilityLabel("Marked reviewed.")
                    }
                }
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
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let reviewPrefix = isReviewed ? "Reviewed." : "Next to review."
        return "\(reviewPrefix) \(lesson.region.displayName) lesson. \(lesson.title). Education only."
    }
}
