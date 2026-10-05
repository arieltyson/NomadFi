// InvestingEducationSection.swift
// NomadFi
//
// "Learn for your jurisdictions" section rendered inside the
// Investing Learn surface. One block per active jurisdiction (home
// first). Each block surfaces:
//
//   • A per-region progress chip ("3 of 9 steps reviewed")
//   • A "Next to review" card when a next step exists
//   • The interactive checklist card
//   • The ordered lesson rows with review badges
//
// All writes are explicit user actions flowing back through the
// closures the parent (`InvestingLearnView`) wires to
// `InvestingLearnViewModel`.

import SwiftUI

struct InvestingEducationSection: View {

    let bundles: [InvestingEducationRegionBundle]
    let progressRecords: [InvestingEducationProgressRecord]
    let summary: (InvestingEducationRegionBundle) -> InvestingEducationRegionProgressSummary
    let nextStep: (InvestingEducationRegionBundle) -> InvestingEducationNextStep?
    let isLessonReviewed: (InvestingEducationLesson) -> Bool
    let isChecklistItemCompleted: (InvestingEducationChecklistItem, InvestingEducationRegion) -> Bool
    let onSelectLesson: (InvestingEducationLesson) -> Void
    let onToggleChecklistItem: (InvestingEducationChecklistItem, InvestingEducationRegion) -> Void

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
            Text("Education only. Not investment advice. Not a substitute for a registered investment professional. NomadFi does not recommend specific funds or accounts.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Region block

    private func regionBlock(_ bundle: InvestingEducationRegionBundle) -> some View {
        let regionSummary = summary(bundle)
        let step = nextStep(bundle)
        return VStack(alignment: .leading, spacing: SpacingTokens.small) {
            regionHeader(for: bundle, summary: regionSummary)
            if let step {
                nextStepCard(for: step)
            }
            InvestingEducationChecklistCard(
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
        }
        .padding(.vertical, SpacingTokens.xxSmall)
    }

    private func regionHeader(
        for bundle: InvestingEducationRegionBundle,
        summary: InvestingEducationRegionProgressSummary
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
                    label: summary.hasCompletedLessonsAndChecklist
                        ? "Reviewed"
                        : "\(summary.totalCompleted) / \(summary.totalTrackable)",
                    color: summary.hasCompletedLessonsAndChecklist ? ColorTokens.positive : ColorTokens.neutral,
                    systemImage: summary.hasCompletedLessonsAndChecklist ? "checkmark.seal" : "book.pages"
                )
                .accessibilityLabel(progressCaption(for: summary))
            }
            Text(progressCaption(for: summary))
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func progressCaption(
        for summary: InvestingEducationRegionProgressSummary
    ) -> String {
        if summary.hasCompletedLessonsAndChecklist {
            return "All starter steps reviewed for \(summary.region.displayName)."
        }
        return "\(summary.totalCompleted) of \(summary.totalTrackable) starter steps reviewed."
    }

    private func nextStepCard(for step: InvestingEducationNextStep) -> some View {
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
        .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: RadiusTokens.small, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next to review. \(step.title).")
    }

    private func lessonsList(for bundle: InvestingEducationRegionBundle) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Lessons")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(bundle.lessons) { lesson in
                Button {
                    onSelectLesson(lesson)
                } label: {
                    InvestingEducationLessonRow(
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
