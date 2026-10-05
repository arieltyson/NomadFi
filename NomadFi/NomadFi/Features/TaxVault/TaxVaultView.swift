// TaxVaultView.swift
// NomadFi
//
// Shell for the Tax Vault destination. Three peer surfaces sit
// under one `NavigationStack` (the Tools tab's), switched via a
// `Picker(.segmented)` so the surface itself feels like one
// coherent workspace rather than three unrelated screens.
//
// Product intent (HIG hierarchy + harmony + ADA social-impact):
//   • `.review`  — in-content scan / upload CTA + the tax-category
//     suggestion queue. First-viewport clarity on "what do I need
//     to act on?".
//   • `.learn`   — source-backed education starter, progression,
//     knowledge-check quizzes, and calm recognition badges. No
//     scan clutter, no archive noise.
//   • `.archive` — searchable document list grouped by year and
//     jurisdiction, with per-year exports. Search only lives here
//     because that is the only surface it meaningfully searches.
//
// Queries, sheet presentations, and the photo-import pipeline stay
// on this shell so each peer view can stay pure about its own job.

import PhotosUI
import SwiftData
import SwiftUI
import TipKit

struct TaxVaultView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaxDocument.documentDate, order: .reverse)
    private var documents: [TaxDocument]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @Query(sort: \TaxEducationProgressRecord.lastInteractedAt, order: .reverse)
    private var progressRecords: [TaxEducationProgressRecord]

    @State private var viewModel = TaxVaultViewModel()
    @State private var suggestionReview = TaxSuggestionReviewViewModel()
    @State private var education = TaxEducationViewModel()
    @State private var surface: TaxVaultSurface = .review
    @State private var showScanError = false

    // Pushed from the Tools tab, so it relies on that tab's
    // `NavigationStack`. Nesting a second stack here would double up
    // the bar and break `.navigationDestination` routing.
    var body: some View {
        VStack(spacing: 0) {
            TaxVaultSurfaceSwitcher(selection: $surface)
            Divider()
            surfaceContent
        }
        .navigationTitle("Tax Vault")
        .toolbar { toolbarContent }
        .task(id: transactions.count) {
            suggestionReview.refresh(from: transactions)
        }
        .task(id: jurisdictions.count) {
            education.refresh(from: jurisdictions)
        }
        .navigationDestination(for: TaxDocument.self) { document in
            TaxDocumentDetailView(document: document)
        }
        .sheet(isPresented: $viewModel.showingConfirmation) {
            ReceiptConfirmationView(viewModel: viewModel)
        }
        .sheet(item: $suggestionReview.selection) { suggestion in
            TaxSuggestionReviewView(
                suggestion: suggestion,
                transactions: transactions,
                viewModel: suggestionReview
            )
        }
        .sheet(item: $education.selection) { lesson in
            TaxEducationLessonDetailView(
                lesson: lesson,
                isReviewed: education.isLessonReviewed(lesson, in: progressRecords),
                onMarkReviewed: {
                    education.markLessonReviewed(
                        lesson,
                        in: modelContext,
                        records: progressRecords
                    )
                },
                onUnmarkReviewed: {
                    education.unmarkLessonReviewed(
                        lesson,
                        in: modelContext,
                        records: progressRecords
                    )
                }
            )
        }
        .sheet(item: $education.quizSelection) { quiz in
            TaxEducationQuizSheet(
                quiz: quiz,
                records: progressRecords
            )
        }
        .overlay {
            if viewModel.isScanning {
                scanningOverlay
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) {
            Task {
                await viewModel.processSelectedPhoto(modelContext: modelContext)
            }
        }
        .alert("Scan Error", isPresented: $showScanError) {
            Button("Try Again") {
                viewModel.scanError = nil
            }
            Button("Dismiss", role: .cancel) {
                viewModel.scanError = nil
            }
        } message: {
            Text(viewModel.scanError ?? "An unexpected error occurred while scanning the receipt.")
        }
        .onChange(of: viewModel.scanError) { _, newValue in
            showScanError = newValue != nil
        }
        .sensoryFeedback(.error, trigger: viewModel.scanError)
        .sensoryFeedback(.success, trigger: viewModel.showingConfirmation)
    }

    // MARK: - Surface routing

    @ViewBuilder
    private var surfaceContent: some View {
        switch surface {
        case .review:
            TaxVaultReviewView(
                suggestions: suggestionReview.suggestions,
                transactions: transactions,
                viewModel: viewModel,
                suggestionReview: suggestionReview
            )
        case .learn:
            TaxVaultLearnView(
                progressRecords: progressRecords,
                modelContext: modelContext,
                education: education,
                jurisdictions: jurisdictions,
                documents: documents,
                onRequestSurface: { requested in
                    surface = requested
                }
            )
        case .archive:
            TaxVaultArchiveView(
                documents: documents,
                jurisdictions: jurisdictions,
                viewModel: viewModel,
                modelContext: modelContext
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Toolbar scan affordance stays for discoverability, but
        // the in-content CTA in Review is the primary path.
        ToolbarItem(placement: .primaryAction) {
            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                Label("Add Receipt", systemImage: "plus")
            }
            .accessibilityHint("Selects a receipt image to scan and add to Tax Vault.")
        }

        if surface == .archive, let exportURL = viewModel.exportURL {
            ToolbarItem(placement: .secondaryAction) {
                ShareLink(item: exportURL) {
                    Label("Share Report", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Shares the most recently exported tax report.")
            }
        }
    }

    // MARK: - Scanning overlay

    private var scanningOverlay: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.medium) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading receipt...")
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Scanning receipt, please wait")
    }
}

// MARK: - Supporting Views

/// Displays a compact summary of category totals within a tax year section.
struct CategorySummaryRow: View {

    let categories: [TaxCategory]
    let documents: [TaxDocument]
    let viewModel: TaxVaultViewModel

    var body: some View {
        if !categories.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: SpacingTokens.xSmall) {
                    ForEach(categories) { category in
                        categoryChip(category)
                    }
                }
                .padding(.vertical, SpacingTokens.xxSmall)
            }
            .scrollIndicators(.hidden)
            .listRowInsets(EdgeInsets(
                top: SpacingTokens.xxSmall,
                leading: SpacingTokens.medium,
                bottom: SpacingTokens.xxSmall,
                trailing: SpacingTokens.medium
            ))
        }
    }

    private func categoryChip(_ category: TaxCategory) -> some View {
        let total = viewModel.categoryTotal(category, in: documents)
        return VStack(spacing: SpacingTokens.xxSmall) {
            Image(systemName: category.systemImage)
                .font(.caption2)
            Text(total, format: .currency(code: "USD"))
                .font(.caption2)
                .bold()
        }
        .padding(.horizontal, SpacingTokens.xSmall)
        .padding(.vertical, SpacingTokens.xxSmall)
        .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: RadiusTokens.small, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName): \(total, format: .currency(code: "USD"))")
    }
}

// MARK: - Tips

/// A TipKit tip encouraging users to scan their first receipt.
/// Now surfaced inline inside the Review surface (near the primary
/// scan CTA) rather than stacked on top of a monolithic list.
struct ScanReceiptTip: Tip {
    var title: Text {
        Text("Scan receipts for tax season")
    }

    var message: Text? {
        Text("NomadFi reads your receipts on device, suggests a category, and waits for you to confirm.")
    }

    var image: Image? {
        Image(systemName: "doc.text.viewfinder")
    }
}

#Preview {
    NavigationStack {
        TaxVaultView()
    }
    .modelContainer(
        for: [
            TaxDocument.self,
            JurisdictionProfile.self,
            Transaction.self,
            TaxEducationProgressRecord.self,
        ],
        inMemory: true
    )
}
