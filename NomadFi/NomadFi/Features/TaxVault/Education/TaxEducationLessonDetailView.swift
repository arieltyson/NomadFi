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
//   7. Explicit "Mark reviewed" / "Mark not reviewed yet" action
//   8. Standing education-only disclaimer
//
// Progress writes are explicit — opening this sheet does not flip
// anything. Only the action button moves the lesson between
// `.completed` and `.notStarted`.

import SwiftData
import SwiftUI

struct TaxEducationLessonDetailView: View {

    let lesson: TaxEducationLesson

    /// Whether the user has already marked this lesson reviewed.
    /// Resolved against live `TaxEducationProgressRecord`s by the
    /// parent view.
    let isReviewed: Bool

    /// Called when the user taps "Mark reviewed".
    let onMarkReviewed: () -> Void

    /// Called when the user taps "Mark not reviewed yet".
    let onUnmarkReviewed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var markedSignature: Int = 0

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
                actionSection
                disclaimerSection
            }
            .navigationTitle("Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: markedSignature)
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

    var actionSection: some View {
        Section {
            if isReviewed {
                Button(role: .destructive) {
                    onUnmarkReviewed()
                    markedSignature &+= 1
                    dismiss()
                } label: {
                    Label("Mark not reviewed yet", systemImage: "arrow.uturn.backward.circle")
                }
                .accessibilityHint("Resets this lesson so it shows up again in the next-to-review queue.")
            } else {
                Button {
                    onMarkReviewed()
                    markedSignature &+= 1
                    dismiss()
                } label: {
                    Label("Mark reviewed", systemImage: "checkmark.seal")
                }
                .accessibilityHint("Saves this lesson as reviewed. NomadFi does not file on your behalf — this is a review flag only.")
            }
        } header: {
            Text("Your review")
        } footer: {
            Text("Reviewed means you read the education content. It does not mean a tax return is done and it does not make the underlying expense deductible.")
                .font(TypographyTokens.caption)
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
