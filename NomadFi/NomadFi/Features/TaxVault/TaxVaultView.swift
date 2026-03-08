// TaxVaultView.swift
// NomadFi
//
// The main Tax Vault landing screen showing documents grouped by
// tax year and jurisdiction with running category totals.

import PhotosUI
import SwiftData
import SwiftUI
import TipKit

/// The Tax Vault landing screen — the organizational hub for tax documents.
///
/// Displays scanned receipts and tax documents grouped by year and jurisdiction,
/// with running totals per category. Provides access to receipt scanning,
/// document detail, and export functionality.
struct TaxVaultView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxDocument.documentDate, order: .reverse) private var documents: [TaxDocument]
    @Query(sort: \JurisdictionProfile.displayOrder) private var jurisdictions: [JurisdictionProfile]
    @State private var viewModel = TaxVaultViewModel()
    @State private var selectedTaxYear: Int?
    @State private var navigationPath = NavigationPath()
    @State private var showScanError = false

    private let scanReceiptTip = ScanReceiptTip()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("Tax Vault")
            .glassToolbar()
            .searchable(text: $viewModel.searchText, prompt: "Search receipts")
            .toolbar { toolbarContent }
            .navigationDestination(for: TaxDocument.self) { document in
                TaxDocumentDetailView(document: document)
            }
            .sheet(isPresented: $viewModel.showingConfirmation) {
                ReceiptConfirmationView(viewModel: viewModel)
                    .glassSheet()
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
    }

    // MARK: - Document List

    private var documentList: some View {
        let filtered = viewModel.filteredDocuments(documents)
        let yearGroups = viewModel.documentsByTaxYear(filtered)

        return List {
            TipView(scanReceiptTip)
                .tipBackground(ColorTokens.surfaceSecondary)

            TipView(TaxExportTip())
                .tipBackground(ColorTokens.surfaceSecondary)

            ForEach(yearGroups, id: \.year) { group in
                taxYearSection(year: group.year, documents: group.documents)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tax Year Section

    private func taxYearSection(year: Int, documents: [TaxDocument]) -> some View {
        Section {
            // Category summary row
            CategorySummaryRow(
                categories: viewModel.activeCategories(in: documents),
                documents: documents,
                viewModel: viewModel
            )

            // Documents grouped by jurisdiction
            let jurisdictionGroups = viewModel.documentsByJurisdiction(
                documents,
                jurisdictions: jurisdictions
            )
            ForEach(jurisdictionGroups, id: \.jurisdiction.id) { group in
                jurisdictionSection(
                    jurisdiction: group.jurisdiction,
                    documents: group.documents
                )
            }

            // Export button for this year
            Button("Export \(String(year)) Tax Report", systemImage: "square.and.arrow.up") {
                Task {
                    await viewModel.exportDocuments(
                        documents,
                        taxYear: year,
                        jurisdictions: jurisdictions
                    )
                }
            }
            .disabled(viewModel.isExporting)
            .accessibilityHint("Creates and exports a report for tax year \(String(year)).")
        } header: {
            HStack {
                Text("Tax Year \(String(year))")
                Spacer()
                Text("\(documents.count) documents")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Jurisdiction Section

    private func jurisdictionSection(
        jurisdiction: JurisdictionProfile,
        documents: [TaxDocument]
    ) -> some View {
        Section {
            ForEach(documents) { document in
                TaxDocumentRow(document: document)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.deleteDocument(document, modelContext: modelContext)
                        }
                    }
            }
        } header: {
            Label(jurisdiction.countryName, systemImage: "flag")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tax Documents", systemImage: "doc.text.viewfinder")
        } description: {
            Text("Scan receipts to start building your tax records. NomadFi auto-categorizes and organizes them by jurisdiction for easy NRA tax filing.")
        } actions: {
            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                Label("Scan a Receipt", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens your photo library to select a receipt image for scanning.")

            TipView(scanReceiptTip)
                .tipBackground(ColorTokens.surfaceSecondary)
                .padding(.top, SpacingTokens.small)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                Label("Add Receipt", systemImage: "plus")
            }
            .accessibilityHint("Selects a receipt image to scan and add to Tax Vault.")
        }

        if let exportURL = viewModel.exportURL {
            ToolbarItem(placement: .secondaryAction) {
                ShareLink(item: exportURL) {
                    Label("Share Report", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Shares the most recently exported tax report.")
            }
        }
    }

    // MARK: - Scanning Overlay

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
        .background(ColorTokens.surfaceTertiary, in: .rect(cornerRadius: SpacingTokens.xSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName): \(total, format: .currency(code: "USD"))")
    }
}

// MARK: - Tips

/// A TipKit tip encouraging users to scan their first receipt.
struct ScanReceiptTip: Tip {
    var title: Text {
        Text("Scan Receipts for Tax Season")
    }

    var message: Text? {
        Text("NomadFi reads your receipts, auto-categorizes them as US Source or Canada Source, and organizes everything for NRA tax filing.")
    }

    var image: Image? {
        Image(systemName: "doc.text.viewfinder")
    }
}

#Preview {
    TaxVaultView()
        .modelContainer(for: [TaxDocument.self, JurisdictionProfile.self], inMemory: true)
}
