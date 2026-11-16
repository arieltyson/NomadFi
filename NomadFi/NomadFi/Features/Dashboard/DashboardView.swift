import SwiftData
import SwiftUI
import TipKit

/// The primary dashboard displaying global net worth, accounts, exchange rates, and insights.
///
/// Uses `@Query` for the few accounts and jurisdictions it shows directly.
/// Everything derived from the transaction history is built off the main
/// thread by `DashboardViewModel`, so loading, scrolling and refreshing
/// never wait on it.
struct DashboardView: View {

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @Query private var accounts: [Account]

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
        .navigationDestination(for: SpendingRoute.self) { route in
            SpendingView(route: route)
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
        .task {
            // Rebuild the digest after saves from anywhere: an import, a
            // sync, a transaction added in the Ledger.
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                viewModel.scheduleDigestRefresh(in: modelContext.container, homeCurrency: homeCurrency)
            }
        }
        .sensoryFeedback(.success, trigger: completedPullRefreshes)
    }
}

// MARK: - Subviews

/// A few things worth a look, most recent first. Only the first
/// ``collapsedCount`` show until the person asks for the rest, so the
/// Dashboard never turns into a list of alerts.
private struct InsightsSection: View {

    let insights: [FinancialInsight]

    /// How many insights show before "Show All".
    static let collapsedCount = 3

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Label("Worth a Look", systemImage: "lightbulb.fill")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            ForEach(isExpanded ? insights : Array(insights.prefix(Self.collapsedCount))) { insight in
                InsightCardView(insight: insight)
            }

            if insights.count > Self.collapsedCount {
                Button(isExpanded ? "Show Less" : "Show All \(insights.count)") {
                    withAnimation(AnimationTokens.standard) { isExpanded.toggle() }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
        }
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
                NavigationLink(value: SpendingRoute(homeCurrency: homeCurrency)) {
                    SpendingTrendCard(summary: trend)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows what kinds of spending and which merchants make up each category.")
                .padding(.horizontal, SpacingTokens.medium)
                .transition(.opacity)
            }

            if !viewModel.insights.isEmpty {
                InsightsSection(insights: viewModel.insights)
                    .padding(.horizontal, SpacingTokens.medium)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.medium)
        // Cards that arrive after the first frame fade in instead of
        // popping, and the cards below them glide into place.
        .animation(reduceMotion ? nil : AnimationTokens.standard, value: viewModel.spendingTrend)
        .animation(reduceMotion ? nil : AnimationTokens.standard, value: viewModel.insights)
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
        // Only the network call holds the control open. The digest is
        // rebuilt on a background worker after it, so the control closes
        // on a free main thread.
        await viewModel.fetchRates(for: viewModel.currencies(from: jurisdictions), force: true)
        if viewModel.lastUpdated != previousUpdate {
            completedPullRefreshes += 1
        }
        Task { await refreshDigestAndWidget() }
    }

    /// Reuses fresh cached rates unless `force` is set, so returning to
    /// the tab or the app does no network work.
    func refreshRates(force: Bool = false) async {
        let currencies = viewModel.currencies(from: jurisdictions)
        await viewModel.fetchRates(for: currencies, force: force)
        await refreshDigestAndWidget()
    }

    func refreshDigestAndWidget() async {
        await viewModel.refreshDigest(in: modelContext.container, homeCurrency: homeCurrency)
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
