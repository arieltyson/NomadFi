import SwiftData
import SwiftUI

/// The transaction ledger displaying a searchable, filterable, date-grouped
/// list of all transactions across jurisdictions.
///
/// Features Active Card recommendation, filter chips, and navigation
/// to transaction details and manual entry.
struct LedgerView: View {

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]

    @State private var viewModel = LedgerViewModel()
    @State private var isShowingAddTransaction = false

    var body: some View {
        Group {
            if transactions.isEmpty && !viewModel.hasActiveFilters {
                emptyState
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
        .task {
            viewModel.requestLocationAuthorizationIfNeeded()
            viewModel.updateFXIntelligence(transactions: transactions)
            await viewModel.updateActiveCardRecommendation(accounts: accounts)
        }
    }
}

// MARK: - Transaction List

private struct DateSectionHeader: View {

    let date: Date

    var body: some View {
        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

// MARK: - Private Helpers

private extension LedgerView {

    var filteredResults: [Transaction] {
        viewModel.filteredTransactions(transactions)
    }

    var groupedResults: [(date: Date, transactions: [Transaction])] {
        viewModel.groupedByDate(filteredResults)
    }

    var transactionList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.small, pinnedViews: .sectionHeaders) {
                activeCardSection

                filterSection

                if filteredResults.isEmpty {
                    noResultsView
                } else {
                    transactionSections
                }
            }
            .padding(.vertical, SpacingTokens.xSmall)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    var activeCardSection: some View {
        if let accountName = viewModel.recommendedAccountName,
           let country = viewModel.currentCountryCode
        {
            ActiveCardBanner(accountName: accountName, countryCode: country)
                .padding(.horizontal, SpacingTokens.medium)
        }
    }

    var filterSection: some View {
        TransactionFilterChips(viewModel: viewModel, jurisdictions: jurisdictions)
    }

    var transactionSections: some View {
        ForEach(groupedResults, id: \.date) { group in
            Section {
                ForEach(group.transactions, id: \.self) { transaction in
                    NavigationLink(value: transaction) {
                        TransactionRowView(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, SpacingTokens.medium)
                }
            } header: {
                DateSectionHeader(date: group.date)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.top, SpacingTokens.xSmall)
            }
        }
        .navigationDestination(for: Transaction.self) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }

    var noResultsView: some View {
        ContentUnavailableView.search(text: viewModel.searchText)
            .padding(.top, SpacingTokens.xxLarge)
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Your cross-border transactions will appear here. Tap + to add one manually.")
        } actions: {
            Button("Add Transaction", systemImage: "plus") {
                isShowingAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
        }
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
