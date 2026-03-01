import SwiftData
import SwiftUI

/// The primary dashboard displaying global net worth, accounts, exchange rates, and insights.
///
/// Uses `@Query` for reactive SwiftData data and `DashboardViewModel`
/// for service calls and derived calculations.
struct DashboardView: View {

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var viewModel = DashboardViewModel()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            if accounts.isEmpty {
                emptyState
            } else {
                dashboardContent
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Dashboard")
        .refreshable { await refreshRates() }
        .task { await refreshRates() }
    }
}

// MARK: - Subviews

private struct InsightsSection: View {

    let insights: [FinancialInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Label("Your Money This Week", systemImage: "lightbulb.fill")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            ForEach(insights) { insight in
                InsightCardView(insight: insight)
            }
        }
        .accessibilityLabel("Financial insights: \(insights.count) recommendation\(insights.count == 1 ? "" : "s") this week")
    }
}

// MARK: - Private Helpers

private extension DashboardView {

    var homeCurrency: CurrencyCode {
        viewModel.homeCurrency(from: jurisdictions)
    }

    var dashboardContent: some View {
        LazyVStack(spacing: SpacingTokens.large, pinnedViews: .sectionHeaders) {
            netWorthCard
                .padding(.horizontal, SpacingTokens.medium)

            exchangeRateTicker
                .padding(.horizontal, SpacingTokens.medium)

            accountSections
                .padding(.horizontal, SpacingTokens.medium)

            if !viewModel.insights.isEmpty {
                InsightsSection(insights: viewModel.insights)
                    .padding(.horizontal, SpacingTokens.medium)
            }
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    var netWorthCard: some View {
        GlobalNetWorthCard(
            totalNetWorth: viewModel.globalNetWorth(accounts: accounts, homeCurrency: homeCurrency),
            homeCurrency: homeCurrency,
            jurisdictionTotals: jurisdictions.map { profile in
                (
                    code: profile.countryCode,
                    name: profile.countryName,
                    amount: viewModel.jurisdictionNetWorth(
                        accounts: accounts,
                        jurisdictionCode: profile.countryCode
                    ),
                    currency: profile.currencyCode ?? .usd
                )
            }
        )
        .animation(reduceMotion ? nil : AnimationTokens.numericCount, value: accounts.count)
    }

    var exchangeRateTicker: some View {
        ExchangeRateTicker(
            rates: viewModel.exchangeRates,
            lastUpdated: viewModel.lastUpdated
        )
    }

    var accountSections: some View {
        ForEach(
            viewModel.accountsByJurisdiction(accounts: accounts, jurisdictions: jurisdictions),
            id: \.profile.countryCode
        ) { group in
            JurisdictionAccountSection(profile: group.profile, accounts: group.accounts)
        }
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("No Accounts", systemImage: "creditcard")
        } description: {
            Text("Add accounts from Settings to see your global net worth.")
        }
    }

    func refreshRates() async {
        let currencies = viewModel.currencies(from: jurisdictions)
        await viewModel.fetchRates(for: currencies)
        viewModel.generateInsights(
            transactions: transactions,
            accounts: accounts,
            homeCurrency: homeCurrency
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
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
