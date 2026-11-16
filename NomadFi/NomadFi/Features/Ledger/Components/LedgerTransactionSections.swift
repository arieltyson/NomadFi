import SwiftData
import SwiftUI

/// The ledger's rows grouped under pinned day headings, fetched one page
/// at a time.
///
/// Owns its own `@Query`, built from the descriptor it is given, so only
/// this view re-renders when rows change, and only the fetched slice is
/// grouped. When the row ``LedgerViewModel/prefetchDistance`` from the end
/// scrolls into view, it asks for the next page, so scrolling never stops
/// at an edge.
struct LedgerTransactionSections: View {

    @Query private var transactions: [Transaction]

    private let searchText: String
    private let onNearEnd: (_ loadedCount: Int) -> Void

    init(
        descriptor: FetchDescriptor<Transaction>,
        searchText: String,
        onNearEnd: @escaping (_ loadedCount: Int) -> Void
    ) {
        _transactions = Query(descriptor, animation: .default)
        self.searchText = searchText
        self.onNearEnd = onNearEnd
    }

    var body: some View {
        let groups = LedgerViewModel.groupedByDate(transactions)
        let prefetchID = transactions.suffix(LedgerViewModel.prefetchDistance).first?.persistentModelID

        if groups.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, SpacingTokens.xxLarge)
        } else {
            ForEach(groups, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        NavigationLink(value: transaction) {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, SpacingTokens.medium)
                        .onAppear {
                            if transaction.persistentModelID == prefetchID {
                                onNearEnd(transactions.count)
                            }
                        }
                    }
                } header: {
                    LedgerDateSectionHeader(date: group.date)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.top, SpacingTokens.xSmall)
                }
            }
        }
    }
}
