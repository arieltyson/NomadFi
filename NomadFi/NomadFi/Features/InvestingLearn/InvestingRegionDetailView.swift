// InvestingRegionDetailView.swift
// NomadFi
//
// One jurisdiction's investing lessons, pushed from its card on
// Investing Learn: what to read next, the starter checklist, and the
// ordered lessons, with the education-only disclaimer at the foot.
//
// All writes are explicit user actions flowing back through the
// closures the parent (`InvestingLearnView`) wires to
// `InvestingLearnViewModel`.

import SwiftUI

struct InvestingRegionDetailView: View {

    let bundle: InvestingEducationRegionBundle
    let summary: InvestingEducationRegionProgressSummary
    let nextStep: InvestingEducationNextStep?
    let isLessonReviewed: (InvestingEducationLesson) -> Bool
    let isChecklistItemCompleted: (InvestingEducationChecklistItem) -> Bool
    let onSelectLesson: (InvestingEducationLesson) -> Void
    let onToggleChecklistItem: (InvestingEducationChecklistItem) -> Void

    var body: some View {
        List {
            if let nextStep {
                Section {
                    nextStepCard(for: nextStep)
                } footer: {
                    Text(progressCaption(for: summary))
                }
            }

            Section {
                InvestingEducationChecklistCard(
                    checklist: bundle.checklist,
                    isCompleted: isChecklistItemCompleted,
                    onToggle: onToggleChecklistItem
                )
            }

            if !bundle.lessons.isEmpty {
                Section {
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
                } header: {
                    Text("Lessons")
                } footer: {
                    Text("Education only. Not investment advice. Not a substitute for a registered investment professional. NomadFi does not recommend specific funds or accounts.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .navigationTitle("\(String.flagEmoji(for: bundle.region.rawValue)) \(bundle.region.displayName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pieces

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
}
