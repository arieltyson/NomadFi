import SwiftData
import SwiftUI
import TipKit

/// The transaction ledger displaying a searchable, filterable, date-grouped
/// list of all transactions across jurisdictions.
///
/// Features Active Card recommendation, filter chips, and navigation
/// to transaction details and manual entry. Rows load a page at a time
/// as the list scrolls, so the ledger opens at once however long the
/// history is.
struct LedgerView: View {

    /// At most one row: enough to tell an empty ledger from a filtered one.
    @Query(LedgerViewModel.anyTransactionDescriptor)
    private var anyTransaction: [Transaction]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]

    @State private var viewModel = LedgerViewModel()
    @State private var isShowingAddTransaction = false
    @State private var showError = false

    var body: some View {
        Group {
            if anyTransaction.isEmpty && !viewModel.hasActiveFilters {
                LedgerEmptyStateView()
            } else {
                transactionList
            }
        }
        .navigationTitle("Ledger")
        .searchable(text: $viewModel.searchText, prompt: "Search transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus") {
                    isShowingAddTransaction = true
                }
            }
        }
        .sheet(isPresented: $isShowingAddTransaction) {
            AddTransactionView()
        }
        .task(id: viewModel.searchText) {
            await viewModel.applySearchText()
        }
        .task {
            viewModel.refreshLocationAuthorizationStatus()
            await viewModel.updateActiveCardRecommendation(accounts: accounts)
        }
        .alert("Location Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }
}

// MARK: - Private Helpers

private extension LedgerView {

    var transactionList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.small, pinnedViews: .sectionHeaders) {
                activeCardSection

                filterSection

                LedgerTransactionSections(
                    descriptor: viewModel.fetchDescriptor,
                    searchText: viewModel.appliedSearchText,
                    onNearEnd: viewModel.loadNextPage(loadedCount:)
                )
            }
            .padding(.vertical, SpacingTokens.xSmall)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: Transaction.self) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }

    @ViewBuilder
    var activeCardSection: some View {
        if let accountName = viewModel.recommendedAccountName,
           let country = viewModel.currentCountryCode
        {
            ActiveCardBanner(
                accountName: accountName,
                countryCode: country,
                feeConfidence: viewModel.recommendedAccountFeeConfidence
            )
            .padding(.horizontal, SpacingTokens.medium)
        } else if !viewModel.isLoadingLocation {
            TipView(ActiveCardTip())
                .tipBackground(ColorTokens.surfaceSecondary)
                .padding(.horizontal, SpacingTokens.medium)
        }
    }

    var filterSection: some View {
        TransactionFilterChips(viewModel: viewModel, jurisdictions: jurisdictions)
    }
}

#Preview {
    NavigationStack {
        LedgerView()
    }
    .modelContainer(for: [
        Currency.self,
        JurisdictionProfile.self,
        Account.self,
        Transaction.self,
        ExchangeRate.self,
        TaxDocument.self,
        Subscription.self,
        Budget.self,
    ], inMemory: true)
}
