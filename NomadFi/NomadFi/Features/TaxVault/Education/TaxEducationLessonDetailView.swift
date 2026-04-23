// TaxEducationLessonDetailView.swift
// NomadFi
//
// Modal detail sheet for a single `TaxEducationLesson`. Sections:
//
//   1. Hero header (region + title)
//   2. "What it is"
//   3. "Why it matters"
//   4. "What to review next" (procedural prompts)
//   5. Official sources (external links)
//   6. "Ask a professional" escalation note, when present
//   7. Standing education-only disclaimer
//
// Read-only. No quizzes, no streaks, no progress persistence.

import SwiftUI

struct TaxEducationLessonDetailView: View {

    let lesson: TaxEducationLesson

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                heroSection
                whatItIsSection
                whyItMattersSection
                reviewNextSection
                sourcesSection
                if let escalation = lesson.escalationNote {
                    escalationSection(note: escalation)
                }
                disclaimerSection
            }
            .navigationTitle("Lesson")
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

private extension TaxEducationLessonDetailView {

    var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
                    Image(systemName: lesson.region.systemImage)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                    Text(lesson.region.displayName)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                Text(lesson.title)
                    .font(TypographyTokens.sectionHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .accessibilityElement(children: .combine)
        }
    }

    var whatItIsSection: some View {
        Section {
            Text(lesson.whatItIs)
                .font(TypographyTokens.body)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("What it is")
        }
    }

    var whyItMattersSection: some View {
        Section {
            Text(lesson.whyItMatters)
                .font(TypographyTokens.body)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Why it matters")
        }
    }

    var reviewNextSection: some View {
        Section {
            ForEach(Array(lesson.whatToReviewNext.enumerated()), id: \.offset) { _, prompt in
                Label {
                    Text(prompt)
                        .font(TypographyTokens.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("What to review next")
        }
    }

    var sourcesSection: some View {
        Section {
            ForEach(lesson.sources) { source in
                Link(destination: source.url) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text(source.title)
                            .font(TypographyTokens.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(source.publisher)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                        Text(source.summary)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the official source in your browser.")
            }
        } header: {
            Text("Official sources")
        }
    }

    func escalationSection(note: String) -> some View {
        Section {
            Label {
                Text(note)
                    .font(TypographyTokens.body)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(ColorTokens.neutral)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Ask a professional")
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
}
