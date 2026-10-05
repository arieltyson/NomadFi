// InvestingLearnView.swift
// NomadFi
//
// Investing Learn destination. Reached from Settings → Advanced
// Tools as a sibling to Tax Vault, so it relies on the ambient
// `NavigationStack` already provided by Settings — nesting another
// stack here would double the nav bar and break routing.
//
// Surface intent (HIG hierarchy + harmony):
//   • Source-backed lessons grouped by the user's active
//     jurisdictions, home first.
//   • A procedural checklist per region with explicit toggles.
//   • A "Next to review" card so the first viewport always shows
//     "what should I read first?" rather than a marketing tile.
//   • Standing education-only disclaimer at the section footer.
//
// Phase 8A explicitly excludes fund tracking, watchlists, and any
// suitability framing — those are deferred to Phase 8B once the
// upstream data sources are sound.

import SwiftData
import SwiftUI

struct InvestingLearnView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query(sort: \InvestingEducationProgressRecord.lastInteractedAt, order: .reverse)
    private var progressRecords: [InvestingEducationProgressRecord]

    @State private var viewModel = InvestingLearnViewModel()

    var body: some View {
        Group {
            if viewModel.hasContent {
                contentList
            } else {
                emptyState
            }
        }
        .navigationTitle("Investing Learn")
        .task(id: jurisdictions.count) {
            viewModel.refresh(from: jurisdictions)
        }
        .sheet(item: $viewModel.selection) { lesson in
            InvestingEducationLessonDetailView(
                lesson: lesson,
                isReviewed: viewModel.isLessonReviewed(lesson, in: progressRecords),
                onMarkReviewed: {
                    viewModel.markLessonReviewed(
                        lesson,
                        in: modelContext,
                        records: progressRecords
                    )
                },
                onUnmarkReviewed: {
                    viewModel.unmarkLessonReviewed(
                        lesson,
                        in: modelContext,
                        records: progressRecords
                    )
                }
            )
        }
    }

    // MARK: - Content

    private var contentList: some View {
        List {
            InvestingEducationSection(
                bundles: viewModel.regionBundles,
                progressRecords: progressRecords,
                summary: { bundle in
                    viewModel.summary(for: bundle, in: progressRecords)
                },
                nextStep: { bundle in
                    viewModel.nextStep(for: bundle, in: progressRecords)
                },
                isLessonReviewed: { lesson in
                    viewModel.isLessonReviewed(lesson, in: progressRecords)
                },
                isChecklistItemCompleted: { item, region in
                    viewModel.isChecklistItemCompleted(
                        item,
                        region: region,
                        in: progressRecords
                    )
                },
                onSelectLesson: { viewModel.select($0) },
                onToggleChecklistItem: { item, region in
                    viewModel.toggleChecklistItem(
                        item,
                        region: region,
                        in: modelContext,
                        records: progressRecords
                    )
                }
            )
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No jurisdictions on file", systemImage: "books.vertical")
        } description: {
            Text("Add a jurisdiction in Settings → Jurisdictions. NomadFi ships short, source-backed investing lessons for supported regions.")
        }
    }
}

#Preview {
    NavigationStack {
        InvestingLearnView()
    }
    .modelContainer(
        for: [
            JurisdictionProfile.self,
            InvestingEducationProgressRecord.self,
        ],
        inMemory: true
    )
}
