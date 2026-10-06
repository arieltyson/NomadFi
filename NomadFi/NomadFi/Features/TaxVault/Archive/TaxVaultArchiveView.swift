// TaxVaultArchiveView.swift
// NomadFi
//
// Archive is the "what's on file" surface — searchable document
// list grouped by tax year and jurisdiction, with per-year export
// actions. Search only lives here (it only meaningfully searches
// documents). Scan / education are intentionally absent.

import SwiftData
import SwiftUI
import TipKit

struct TaxVaultArchiveView: View {

    let documents: [TaxDocument]
    let jurisdictions: [JurisdictionProfile]

    @Bindable var viewModel: TaxVaultViewModel
    let modelContext: ModelContext

    private let exportTip = TaxExportTip()

    var body: some View {
        Group {
            if documents.isEmpty {
                emptyState
            } else {
                archiveList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search receipts")
    }

    // MARK: - List

    private var archiveList: some View {
        let filtered = viewModel.filteredDocuments(documents)
        let yearGroups = viewModel.documentsByTaxYear(filtered)

        return List {
            TipView(exportTip)
                .tipBackground(ColorTokens.surfaceSecondary)

            if yearGroups.isEmpty {
                searchEmptySection
            } else {
                ForEach(yearGroups, id: \.year) { group in
                    taxYearSection(year: group.year, documents: group.documents)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
    }

    // MARK: - Tax year section

    private func taxYearSection(year: Int, documents: [TaxDocument]) -> some View {
        Section {
            CategorySummaryRow(
                categories: viewModel.activeCategories(in: documents),
                documents: documents,
                viewModel: viewModel
            )

            let jurisdictionGroups = viewModel.documentsByJurisdiction(
                documents,
                jurisdictions: jurisdictions
            )
            ForEach(jurisdictionGroups) { group in
                jurisdictionSection(group)
            }

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

    private func jurisdictionSection(_ group: TaxDocumentJurisdictionGroup) -> some View {
        Section {
            ForEach(group.documents) { document in
                TaxDocumentRow(document: document)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.deleteDocument(document, modelContext: modelContext)
                        }
                    }
            }
        } header: {
            Label(group.title, systemImage: "flag")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty / no-result states

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No documents yet", systemImage: "tray")
        } description: {
            Text("Tap + to scan your first receipt.")
        }
    }

    private var searchEmptySection: some View {
        Section {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }
}
