import SwiftData
import SwiftUI
import TipKit

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
    @State private var showError = false
    /// Counts refreshes the person asked for, so only those are confirmed
    /// with a haptic — never a silent refresh on launch or tab return.
    @State private var completedPullRefreshes = 0

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if accounts.isEmpty {
                DashboardEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, SpacingTokens.medium)
            } else {
                ScrollView {
                    dashboardContent
                }
                .scrollIndicators(.hidden)
            }
        }
        .background {
            LinearGradient(
                colors: [ColorTokens.brandPrimary.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Dashboard")
        .navigationDestination(for: JurisdictionProfile.self) { profile in
            JurisdictionDetailView(profile: profile)
        }
        // Run the refresh in its own task: a refresh tied to the view is
        // cancelled when the view redraws mid-refresh, which can leave the
        // control hanging open.
        .refreshable { await Task { await pullToRefresh() }.value }
        .task {
            AddMoreAccountsTip.accountCount = accounts.count
            await refreshRates()
        }
        .task(id: widgetSnapshotSignature) {
            viewModel.publishWidgetSnapshot(
                accounts: accounts,
                jurisdictions: jurisdictions
            )
        }
        .alert("Something Went Wrong", isPresented: $showError) {
            Button("Retry") {
                Task { await refreshRates() }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshRates() }
            }
        }
        .onChange(of: transactions.count) { _, _ in
            viewModel.recomputeSpendingTrend(
                transactions: transactions,
                homeCurrency: homeCurrency
            )
        }
        .sensoryFeedback(.success, trigger: completedPullRefreshes)
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

    /// Whether this is the initial load (no data yet from the network).
    var isFirstLoad: Bool {
        viewModel.isLoading && viewModel.exchangeRates.isEmpty
    }

    /// Stable change token for widget snapshot updates.
    var widgetSnapshotSignature: Int {
        var hasher = Hasher()
        hasher.combine(homeCurrency.rawValue)
        hasher.combine(jurisdictions.count)
        hasher.combine(accounts.count)
        hasher.combine(viewModel.lastUpdated?.timeIntervalSinceReferenceDate ?? 0)

        for account in accounts.sorted(by: {
            if $0.institutionName == $1.institutionName {
                return $0.name < $1.name
            }

            return $0.institutionName < $1.institutionName
        }) {
            hasher.combine(account.institutionName)
            hasher.combine(account.name)
            hasher.combine(account.netWorthContribution)
            hasher.combine(account.isExcludedFromNetWorth)
            hasher.combine(account.currencyCodeRawValue)
            hasher.combine(account.lastUpdatedAt.timeIntervalSinceReferenceDate)
        }

        return hasher.finalize()
    }

    var dashboardContent: some View {
        LazyVStack(spacing: SpacingTokens.large) {
            netWorthCard
                .redacted(reason: isFirstLoad ? .placeholder : [])
                .padding(.horizontal, SpacingTokens.medium)

            if excludedCreditCardsCount > 0 {
                excludedCreditCardsNote
                    .padding(.horizontal, SpacingTokens.medium)
            }

            VStack(spacing: SpacingTokens.small) {
                jurisdictionCards
            }
            .padding(.horizontal, SpacingTokens.medium)

            TipView(AddMoreAccountsTip())
                .tipBackground(ColorTokens.surfaceSecondary)
                .padding(.horizontal, SpacingTokens.medium)

            if let trend = viewModel.spendingTrend {
                SpendingTrendCard(summary: trend)
                    .padding(.horizontal, SpacingTokens.medium)
            }

            if !viewModel.insights.isEmpty {
                InsightsSection(insights: viewModel.insights)
                    .padding(.horizontal, SpacingTokens.medium)
            }
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    var excludedCreditCardsCount: Int {
        viewModel.excludedCreditCardsCount(accounts: accounts)
    }

    var excludedCreditCardsNote: some View {
        let count = excludedCreditCardsCount
        let cardWord = count == 1 ? "card" : "cards"
        return Label {
            Text("\(count) credit \(cardWord) \(count == 1 ? "is" : "are") not counted because no current balance is saved. Add a balance from Settings to include \(count == 1 ? "it" : "them").")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    var netWorthCard: some View {
        GlobalNetWorthCard(
            totalNetWorth: viewModel.globalNetWorth(accounts: accounts, homeCurrency: homeCurrency),
            homeCurrency: homeCurrency
        )
        .animation(reduceMotion ? nil : AnimationTokens.numericCount, value: accounts.count)
    }

    var jurisdictionCards: some View {
        ForEach(
            viewModel.jurisdictionSummaries(accounts: accounts, jurisdictions: jurisdictions)
        ) { summary in
            NavigationLink(value: summary.profile) {
                JurisdictionCard(summary: summary)
            }
            .buttonStyle(.plain)
        }
    }

    func pullToRefresh() async {
        let previousUpdate = viewModel.lastUpdated
        // Only the network call holds the control open. Insights and the
        // trend are recomputed after it closes, so that work over every
        // transaction never lands on the frame the control animates away.
        await viewModel.fetchRates(for: viewModel.currencies(from: jurisdictions), force: true)
        if viewModel.lastUpdated != previousUpdate {
            completedPullRefreshes += 1
        }
        Task { await refreshRates() }
    }

    /// Reuses fresh cached rates unless `force` is set, so returning to
    /// the tab or the app does no network work.
    func refreshRates(force: Bool = false) async {
        let currencies = viewModel.currencies(from: jurisdictions)
        await viewModel.fetchRates(for: currencies, force: force)
        viewModel.generateInsights(
            transactions: transactions,
            accounts: accounts,
            homeCurrency: homeCurrency
        )
        viewModel.recomputeSpendingTrend(
            transactions: transactions,
            homeCurrency: homeCurrency
        )

        viewModel.publishWidgetSnapshot(
            accounts: accounts,
            jurisdictions: jurisdictions
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
        ScenarioDecisionRecord.self,
    ], inMemory: true)
}
