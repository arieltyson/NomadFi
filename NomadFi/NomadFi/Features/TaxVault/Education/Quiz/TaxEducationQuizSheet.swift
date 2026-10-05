// TaxEducationQuizSheet.swift
// NomadFi
//
// Modal sheet for taking a region's knowledge-check quiz. Two
// phases:
//
//   1. Taking — a Form with question rows + Picker-style options.
//   2. Result — correct count, percent, pass/fail, Retake button.
//
// No timers, no difficulty picker. The surface
// stays instructional and explicit — nothing submits or writes
// without the user tapping Submit.

import SwiftData
import SwiftUI

struct TaxEducationQuizSheet: View {

    let quiz: TaxEducationQuiz
    let records: [TaxEducationProgressRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var session = TaxEducationQuizSessionViewModel()

    var body: some View {
        NavigationStack {
            Form {
                heroSection
                if let result = session.latestResult {
                    resultSection(result)
                    retakeSection
                } else {
                    questionsSection
                    submitSection
                }
                disclaimerSection
            }
            .navigationTitle(quiz.region.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sections

private extension TaxEducationQuizSheet {

    var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Image(systemName: quiz.region.systemImage)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                    Text("Knowledge check")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                Text(quiz.title)
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)
                Text(quiz.summary)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    var questionsSection: some View {
        Section {
            ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                questionBlock(question, number: index + 1)
            }
        } header: {
            Text("Questions")
        }
    }

    func questionBlock(
        _ question: TaxEducationQuizQuestion,
        number: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Question \(number) of \(quiz.questionCount)")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
            Text(question.prompt)
                .font(TypographyTokens.body)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(question.options) { option in
                optionRow(option, for: question)
            }
        }
        .padding(.vertical, SpacingTokens.xxSmall)
    }

    func optionRow(
        _ option: TaxEducationQuizOption,
        for question: TaxEducationQuizQuestion
    ) -> some View {
        let isSelected = session.selection(for: question) == option.id
        return Button {
            session.select(option: option.id, for: question)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? ColorTokens.brandPrimary : ColorTokens.neutral)
                    .accessibilityHidden(true)
                Text(option.text)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(isSelected ? "Selected. \(option.text)" : option.text)
    }

    var submitSection: some View {
        Section {
            Button {
                _ = session.submit(
                    quiz: quiz,
                    in: modelContext,
                    records: records
                )
            } label: {
                Label("Submit answers", systemImage: "checkmark.circle")
            }
            .disabled(!session.canSubmit(quiz))
            .accessibilityHint("Scores your answers and saves the attempt. NomadFi does not file anything on your behalf.")
        } footer: {
            if !session.canSubmit(quiz) {
                Text("Pick an option for every question to enable Submit.")
                    .font(TypographyTokens.caption)
            }
        }
    }

    func resultSection(_ result: TaxEducationQuizResult) -> some View {
        Section {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Image(systemName: result.didPass ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .foregroundStyle(result.didPass ? ColorTokens.positive : ColorTokens.warning)
                        .accessibilityHidden(true)
                    Text(result.didPass ? "Reviewed" : "Needs more review")
                        .font(TypographyTokens.sectionHeader)
                }
                Text("\(result.correctCount) of \(result.questionCount) correct · \(formattedPercent(result.scorePercent))")
                    .font(TypographyTokens.body)
                    .monospacedDigit()
                Text(result.didPass
                    ? "Education only — this review does not mean a tax return is done."
                    : "\(Int(TaxEducationQuizScoring.passThresholdPercent))% or more passes. Revisit the lesson above and retake any time.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Your result")
        }
    }

    var retakeSection: some View {
        Section {
            Button(role: .destructive) {
                session.retake()
            } label: {
                Label("Retake", systemImage: "arrow.clockwise")
            }
            .accessibilityHint("Clears your answers so you can review and try again.")
        }
    }

    var disclaimerSection: some View {
        Section {
            Label {
                Text("Education only. Not a substitute for a qualified professional. NomadFi does not file on your behalf.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(ColorTokens.neutral)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Reminder")
        }
    }

    func formattedPercent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0...1)))
    }
}
