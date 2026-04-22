// SubscriptionsView.swift
// NomadFi
//
// Main subscription management screen showing tracked subscriptions,
// savings opportunities, and new subscription candidates.

import SwiftData
import SwiftUI
import TipKit

/// Displays the user's subscriptions with cross-border price comparison
/// and savings opportunities.
///
/// Organized into sections: savings summary, tracked subscriptions,
/// and newly detected candidates. Supports search and swipe-to-delete.
struct SubscriptionsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Subscription.serviceName)
    private var subscriptions: [Subscription]

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel = SubscriptionsViewModel()
    @State private var isShowingAddSubscription = false
    @State private var showError = false

    // Subscriptions is now an optional companion under Settings →
    // Advanced Tools rather than a primary tab, so it relies on the
    // ambient `NavigationStack` from Settings. Nesting a second stack
    // here would double up the nav bar.
    var body: some View {
        Group {
            if subscriptions.isEmpty && viewModel.detectedSubscriptions.isEmpty {
                emptyState
            } else {
                subscriptionList
            }
        }
        .navigationTitle("Subscriptions")
        .glassToolbar()
        .searchable(text: $viewModel.searchText, prompt: "Search subscriptions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Subscription", systemImage: "plus") {
                    isShowingAddSubscription = true
                }
            }
        }
        .sheet(isPresented: $isShowingAddSubscription) {
            AddSubscriptionView()
                .glassSheet()
        }
        .task {
            viewModel.detectSubscriptions(
                transactions: transactions,
                existingSubscriptions: subscriptions
            )

            let homeCurrency = viewModel.homeCurrency(from: jurisdictions)
            await viewModel.compareSubscriptions(
                subscriptions: subscriptions,
                jurisdictions: jurisdictions,
                homeCurrency: homeCurrency
            )
        }
        .alert("Comparison Error", isPresented: $showError) {
            Button("Retry") {
                Task {
                    let homeCurrency = viewModel.homeCurrency(from: jurisdictions)
                    await viewModel.compareSubscriptions(
                        subscriptions: subscriptions,
                        jurisdictions: jurisdictions,
                        homeCurrency: homeCurrency
                    )
                }
            }
            Button("Dismiss", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Could not compare subscription prices.")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }
}

// MARK: - List Content

private extension SubscriptionsView {

    var subscriptionList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.medium) {
                savingsSummary

                if !viewModel.detectedSubscriptions.isEmpty {
                    detectedSection
                }

                TipView(SubscriptionArbitrageTip())
                    .tipBackground(ColorTokens.surfaceSecondary)
                    .padding(.horizontal, SpacingTokens.medium)

                if viewModel.isComparing {
                    savingsOpportunitiesPlaceholder
                } else if !viewModel.comparisonResults.isEmpty {
                    savingsOpportunitiesSection
                }

                trackedSection
            }
            .padding(.vertical, SpacingTokens.xSmall)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Savings Summary Card

    var savingsSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                Text("Monthly Subscription Cost")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                let homeCurrency = viewModel.homeCurrency(from: jurisdictions)

                CurrencyText(
                    amount: viewModel.totalMonthlyCost(subscriptions),
                    currencyCode: homeCurrency,
                    font: TypographyTokens.amountMedium
                )
                .bold()

                if viewModel.totalAnnualSavings > 0 {
                    StatusBadge(
                        label: "Savings Opportunity Active",
                        color: ColorTokens.positive,
                        systemImage: "arrow.down.circle.fill"
                    )

                    Text("Save \(viewModel.totalAnnualSavings, format: .currency(code: homeCurrency.rawValue))/year with subscription arbitrage")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.positive)
                }

                Text("\(subscriptions.count) active subscription\(subscriptions.count == 1 ? "" : "s")")
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, SpacingTokens.medium)
        .accessibilityElement(children: .combine)
    }

    // MARK: Detected Candidates

    var detectedSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Detected Subscriptions")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SpacingTokens.medium)

            Text("We found these recurring charges in your transactions.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SpacingTokens.medium)

            ForEach(
                viewModel.detectedSubscriptions.indices,
                id: \.self
            ) { index in
                let detection = viewModel.detectedSubscriptions[index]
                DetectedSubscriptionCard(
                    detection: detection,
                    onConfirm: {
                        viewModel.confirmSubscription(detection, modelContext: modelContext)
                    },
                    onDismiss: {
                        viewModel.dismissDetection(detection)
                    }
                )
                .padding(.horizontal, SpacingTokens.medium)
            }
        }
    }

    // MARK: Savings Opportunities

    var savingsOpportunitiesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Savings Opportunities")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SpacingTokens.medium)

            ForEach(viewModel.comparisonResults) { result in
                SavingsOpportunityCard(result: result)
                    .padding(.horizontal, SpacingTokens.medium)
            }
        }
    }

    // MARK: Savings Placeholder (Skeleton)

    /// Skeleton placeholder while subscription comparison is loading.
    var savingsOpportunitiesPlaceholder: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Savings Opportunities")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SpacingTokens.medium)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    Text("Comparing prices across jurisdictions...")
                        .font(TypographyTokens.body)
                        .foregroundStyle(.secondary)

                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, SpacingTokens.medium)
            .redacted(reason: .placeholder)
        }
    }

    // MARK: Tracked Subscriptions

    var trackedSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Your Subscriptions")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, SpacingTokens.medium)

            let filtered = viewModel.filteredSubscriptions(subscriptions)
            if filtered.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .padding(.top, SpacingTokens.xxLarge)
            } else {
                ForEach(filtered) { subscription in
                    SubscriptionRowView(
                        subscription: subscription,
                        homeCurrency: viewModel.homeCurrency(from: jurisdictions)
                    )
                    .padding(.horizontal, SpacingTokens.medium)
                }
            }
        }
    }

    // MARK: Empty State

    var emptyState: some View {
        ContentUnavailableView {
            Label("No Subscriptions", systemImage: "arrow.triangle.2.circlepath")
        } description: {
            Text("Add transactions to auto-detect subscriptions, or add them manually.")
        } actions: {
            Button("Add Subscription", systemImage: "plus") {
                isShowingAddSubscription = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionsView()
    }
    .modelContainer(for: [
        Subscription.self,
        Transaction.self,
        JurisdictionProfile.self,
        Account.self,
        ExchangeRate.self,
        TaxDocument.self,
        Currency.self,
        Budget.self,
    ], inMemory: true)
}
