// TaxEducationSection.swift
// NomadFi
//
// "Learn for your jurisdictions" section rendered near the top of
// `TaxVaultView`. One region block per active jurisdiction (home
// first). Each block now surfaces:
//
//   • A per-region progress chip ("3 of 7 steps reviewed")
//   • A "Next to review" card when a next step exists
//   • The interactive checklist card
//   • The ordered lesson rows with review badges
//
// All writes are explicit user actions flowing back through the
// closures the parent (`TaxVaultView`) wires to
// `TaxEducationViewModel`.

import SwiftUI

struct TaxEducationSection: View {

    let bundles: [TaxEducationRegionBundle]
    let progressRecords: [TaxEducationProgressRecord]
    let summary: (TaxEducationRegionBundle) -> TaxEducationRegionProgressSummary
    let nextStep: (TaxEducationRegionBundle) -> TaxEducationNextStep?
    let isLessonReviewed: (TaxEducationLesson) -> Bool
    let isChecklistItemCompleted: (TaxEducationChecklistItem, TaxEducationRegion) -> Bool
    let isQuizUnlocked: (TaxEducationRegionBundle) -> Bool
    let onSelectLesson: (TaxEducationLesson) -> Void
    let onToggleChecklistItem: (TaxEducationChecklistItem, TaxEducationRegion) -> Void
    let onOpenQuiz: (TaxEducationQuiz) -> Void

    var body: some View {
        Section {
            ForEach(bundles) { bundle in
                regionBlock(bundle)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Label("Learn for your jurisdictions", systemImage: "books.vertical")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(bundles.count)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } footer: {
            Text("Education only. Not a substitute for a qualified professional. NomadFi does not file on your behalf.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Region block

    private func regionBlock(_ bundle: TaxEducationRegionBundle) -> some View {
        let regionSummary = summary(bundle)
        let step = nextStep(bundle)
        return VStack(alignment: .leading, spacing: SpacingTokens.small) {
            regionHeader(for: bundle, summary: regionSummary)
            if let step {
                nextStepCard(for: step)
            }
            TaxEducationChecklistCard(
                checklist: bundle.checklist,
                isCompleted: { item in
                    isChecklistItemCompleted(item, bundle.region)
                },
                onToggle: { item in
                    onToggleChecklistItem(item, bundle.region)
                }
            )
            if !bundle.lessons.isEmpty {
                lessonsList(for: bundle)
            }
            if let quiz = bundle.quiz {
                TaxEducationQuizRow(
                    quiz: quiz,
                    summary: regionSummary,
                    isUnlocked: isQuizUnlocked(bundle),
                    onOpen: { onOpenQuiz(quiz) }
                )
            }
        }
        .padding(.vertical, SpacingTokens.xxSmall)
    }

    private func regionHeader(
        for bundle: TaxEducationRegionBundle,
        summary: TaxEducationRegionProgressSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Image(systemName: bundle.region.systemImage)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
                Text(bundle.region.displayName)
                    .font(TypographyTokens.sectionHeader)
                if bundle.isHome {
                    StatusBadge(
                        label: "Home",
                        color: ColorTokens.positive,
                        systemImage: "house"
                    )
                    .accessibilityLabel("Home jurisdiction.")
                }
                Spacer()
                StatusBadge(
                    label: summary.isReviewed ? "Reviewed" : "\(summary.stepsReviewed) / \(summary.stepsTotal)",
                    color: summary.isReviewed ? ColorTokens.positive : ColorTokens.neutral,
                    systemImage: summary.isReviewed ? "checkmark.seal" : "book.pages"
                )
                .accessibilityLabel(summary.displayCaption)
            }
            Text(summary.displayCaption)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func nextStepCard(for step: TaxEducationNextStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Next to review")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                Text(step.title)
                    .font(TypographyTokens.body)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)
                if !step.subtitle.isEmpty {
                    Text(step.subtitle)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(SpacingTokens.small)
        .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: SpacingTokens.xSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next to review. \(step.title).")
    }

    private func lessonsList(for bundle: TaxEducationRegionBundle) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Lessons")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(bundle.lessons) { lesson in
                Button {
                    onSelectLesson(lesson)
                } label: {
                    TaxEducationLessonRow(
                        lesson: lesson,
                        isReviewed: isLessonReviewed(lesson)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the full lesson detail.")
            }
        }
    }
}
