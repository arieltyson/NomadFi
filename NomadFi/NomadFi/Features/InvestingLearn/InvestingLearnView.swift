// InvestingLearnView.swift
// NomadFi
//
// Investing Learn destination, pushed from the Tools tab, so it relies
// on that tab's `NavigationStack`.
//
// Surface intent: one card per active jurisdiction (home first), each
// showing how far through its starter steps the person is. A card
// opens the region's next step, checklist and lessons, so nobody
// scrolls past one country's material to reach another's.
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
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                ForEach(viewModel.regionBundles) { bundle in
                    NavigationLink(value: bundle.region) {
                        InvestingRegionCard(summary: viewModel.summary(for: bundle, in: progressRecords))
                    }
                    .buttonStyle(.card)
                }

                Text("Education only. Not investment advice.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(SpacingTokens.medium)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: InvestingEducationRegion.self) { region in
            if let bundle = viewModel.bundle(for: region) {
                InvestingRegionDetailView(
                    bundle: bundle,
                    summary: viewModel.summary(for: bundle, in: progressRecords),
                    nextStep: viewModel.nextStep(for: bundle, in: progressRecords),
                    isLessonReviewed: { viewModel.isLessonReviewed($0, in: progressRecords) },
                    isChecklistItemCompleted: { item in
                        viewModel.isChecklistItemCompleted(item, region: region, in: progressRecords)
                    },
                    onSelectLesson: { viewModel.select($0) },
                    onToggleChecklistItem: { item in
                        viewModel.toggleChecklistItem(
                            item,
                            region: region,
                            in: modelContext,
                            records: progressRecords
                        )
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No jurisdictions on file", systemImage: "books.vertical")
        } description: {
            Text("Add a supported jurisdiction in Settings → Financial Setup.")
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
