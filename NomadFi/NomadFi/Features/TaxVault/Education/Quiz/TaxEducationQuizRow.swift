// TaxEducationQuizRow.swift
// NomadFi
//
// "Knowledge check" card surfaced inside each region block. Four
// visual states driven by the region's `TaxEducationRegionProgressSummary`:
//
//   • Locked — checklist + lessons not fully reviewed yet.
//   • Ready — checklist + lessons done, quiz untouched.
//   • Attempted — a previous attempt exists but didn't pass.
//   • Passed — a previous attempt cleared the pass threshold.
//
// Tap opens the quiz sheet via the `onOpen` callback when the
// quiz is unlocked. The row never auto-opens or auto-submits.

import SwiftUI

struct TaxEducationQuizRow: View {

    let quiz: TaxEducationQuiz
    let summary: TaxEducationRegionProgressSummary
    let isUnlocked: Bool
    let onOpen: () -> Void

    var body: some View {
        Button {
            guard isUnlocked else { return }
            onOpen()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                Image(systemName: leadingSystemImage)
                    .foregroundStyle(leadingColor)
                    .font(.title3)
                    .frame(width: 26, alignment: .center)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                        Text(quiz.title)
                            .font(TypographyTokens.body)
                            .bold()
                            .fixedSize(horizontal: false, vertical: true)
                        statusBadge
                    }
                    Text(supportingCaption)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: SpacingTokens.xSmall)

                if isUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, SpacingTokens.xxSmall)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - State-derived

    private var leadingSystemImage: String {
        if !isUnlocked { return "lock" }
        if summary.quizPassed { return "checkmark.seal.fill" }
        if summary.quizAttemptedNotPassed { return "arrow.clockwise" }
        return "questionmark.circle"
    }

    private var leadingColor: Color {
        if !isUnlocked { return ColorTokens.neutral }
        if summary.quizPassed { return ColorTokens.positive }
        if summary.quizAttemptedNotPassed { return ColorTokens.warning }
        return ColorTokens.brandPrimary
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !isUnlocked {
            StatusBadge(
                label: "Locked",
                color: ColorTokens.neutral,
                systemImage: "lock"
            )
        } else if summary.quizPassed, let score = summary.quizScorePercent {
            StatusBadge(
                label: "Passed · \(formattedPercent(score))",
                color: ColorTokens.positive,
                systemImage: "checkmark"
            )
        } else if summary.quizAttemptedNotPassed, let score = summary.quizScorePercent {
            StatusBadge(
                label: "Needs review · \(formattedPercent(score))",
                color: ColorTokens.warning,
                systemImage: "arrow.clockwise"
            )
        } else {
            StatusBadge(
                label: "Ready",
                color: ColorTokens.brandPrimary,
                systemImage: "play"
            )
        }
    }

    private var supportingCaption: String {
        if !isUnlocked {
            return "Unlocks after every checklist item and lesson above is reviewed."
        }
        if summary.quizPassed {
            return "You answered \(summary.quizCorrectCount ?? 0) of \(summary.quizQuestionCount ?? quiz.questionCount) correctly. Retake any time to refresh your review."
        }
        if summary.quizAttemptedNotPassed {
            return "Review the lesson above, then retake. \(Int(TaxEducationQuizScoring.passThresholdPercent))% or more passes."
        }
        return "\(quiz.questionCount) short questions based on the lessons above."
    }

    private var accessibilityLabel: String {
        if !isUnlocked {
            return "Knowledge check locked. Finish the checklist and lessons above first."
        }
        if summary.quizPassed, let score = summary.quizScorePercent {
            return "Knowledge check passed at \(formattedPercent(score)). Tap to retake."
        }
        if summary.quizAttemptedNotPassed, let score = summary.quizScorePercent {
            return "Knowledge check needs review. Last score \(formattedPercent(score)). Tap to retake."
        }
        return "Knowledge check ready. \(quiz.questionCount) questions."
    }

    private var accessibilityHint: String {
        isUnlocked
            ? "Opens the knowledge-check sheet for this jurisdiction."
            : "Review the checklist items and lessons above to unlock the knowledge check."
    }

    private func formattedPercent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", rounded)
    }
}
