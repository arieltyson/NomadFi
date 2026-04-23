// TaxVaultLearnView.swift
// NomadFi
//
// Learn is the "understand it" surface — source-backed education
// starter, per-region progression, knowledge-check quizzes, and a
// calm recognition strip. No scan CTA here (that belongs to
// Review), no archive noise (that belongs to Archive).

import SwiftData
import SwiftUI

struct TaxVaultLearnView: View {

    let progressRecords: [TaxEducationProgressRecord]
    let modelContext: ModelContext

    @Bindable var education: TaxEducationViewModel

    /// Derived per refresh — recomputed as the VM bundles change.
    var recognition: TaxEducationRecognitionSummary {
        TaxEducationRecognitionComputer.summary(
            for: education.regionBundles,
            in: progressRecords
        )
    }

    var body: some View {
        if education.hasContent {
            List {
                if !recognition.portfolioBadges.isEmpty {
                    recognitionSection
                }
                TaxEducationSection(
                    bundles: education.regionBundles,
                    progressRecords: progressRecords,
                    summary: { bundle in
                        education.summary(for: bundle, in: progressRecords)
                    },
                    nextStep: { bundle in
                        education.nextStep(for: bundle, in: progressRecords)
                    },
                    isLessonReviewed: { lesson in
                        education.isLessonReviewed(lesson, in: progressRecords)
                    },
                    isChecklistItemCompleted: { item, region in
                        education.isChecklistItemCompleted(
                            item,
                            region: region,
                            in: progressRecords
                        )
                    },
                    isQuizUnlocked: { bundle in
                        education.isQuizUnlocked(for: bundle, in: progressRecords)
                    },
                    regionBadges: { region in
                        recognition.badgesByRegion[region] ?? []
                    },
                    onSelectLesson: { education.select($0) },
                    onToggleChecklistItem: { item, region in
                        education.toggleChecklistItem(
                            item,
                            region: region,
                            in: modelContext,
                            records: progressRecords
                        )
                    },
                    onOpenQuiz: { education.selectQuiz($0) }
                )
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
        } else {
            emptyState
        }
    }

    // MARK: - Sections

    private var recognitionSection: some View {
        Section {
            TaxEducationRecognitionStrip(summary: recognition)
                .listRowInsets(EdgeInsets(
                    top: SpacingTokens.xSmall,
                    leading: SpacingTokens.medium,
                    bottom: SpacingTokens.xSmall,
                    trailing: SpacingTokens.medium
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No jurisdictions on file", systemImage: "books.vertical")
        } description: {
            Text("Add a jurisdiction in Settings → Jurisdictions. NomadFi ships short, source-backed lessons for supported regions.")
        }
    }
}
