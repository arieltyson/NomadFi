import SwiftData
import SwiftUI

/// Where the money went, by category, for a chosen period.
///
/// Opens from the Dashboard's trend card. A wheel (or bars) shows the
/// shares; each category opens its own breakdown into finer kinds of
/// spending and the merchants behind them.
struct SpendingView: View {

    @State private var viewModel: SpendingViewModel
    @AppStorage(SpendingChartStyle.storageKey) private var chartStyle = SpendingChartStyle.wheel

    @Environment(\.modelContext) private var modelContext

    init(route: SpendingRoute) {
        _viewModel = State(initialValue: SpendingViewModel(homeCurrency: route.homeCurrency))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                Picker("Period", selection: $viewModel.period) {
                    ForEach(SpendingPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                SpendingIntervalNavigator(viewModel: viewModel)

                SpendingOverviewContent(viewModel: viewModel, chartStyle: chartStyle)
            }
            .padding(SpacingTokens.medium)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Spending")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SpendingChartStyleButton(style: $chartStyle)
            }
        }
        .navigationDestination(for: SpendingCategoryRoute.self) { route in
            SpendingCategoryView(category: route.category, viewModel: viewModel)
        }
        .task(id: viewModel.interval) {
            await viewModel.load(in: modelContext.container)
            await viewModel.sortUnrecognizedMerchants(in: modelContext.container)
        }
        .task {
            // Purchases synced or added while the screen is open, and
            // merchants sorted elsewhere, show up without leaving.
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                viewModel.scheduleReload(in: modelContext.container)
            }
        }
    }
}

/// The Spending screen below its period picker: loading, empty, or the
/// chart and its categories.
private struct SpendingOverviewContent: View {

    let viewModel: SpendingViewModel
    let chartStyle: SpendingChartStyle

    @State private var selectedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let breakdown = viewModel.breakdown {
            if breakdown.categories.isEmpty {
                ContentUnavailableView(
                    "No Spending",
                    systemImage: "chart.pie",
                    description: Text("Purchases from this period will appear here.")
                )
            } else {
                let slices = SpendingViewModel.categorySlices(of: breakdown)
                VStack(spacing: SpacingTokens.large) {
                    SpendingChart(
                        slices: slices,
                        total: breakdown.total,
                        currency: breakdown.currency,
                        caption: String(localized: "Total"),
                        style: chartStyle,
                        selectedID: $selectedID
                    )

                    SurfaceCard {
                        VStack(spacing: .zero) {
                            ForEach(slices) { slice in
                                if let category = TransactionCategory(rawValue: slice.id) {
                                    NavigationLink(value: SpendingCategoryRoute(category: category)) {
                                        SpendingSliceRow(
                                            slice: slice,
                                            currency: breakdown.currency,
                                            accessory: .navigates,
                                            isHighlighted: slice.id == selectedID
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SpendingCurrencyNote(otherCurrencyCount: breakdown.otherCurrencyCount)
                }
                .opacity(viewModel.isLoading ? ColorTokens.chartDimmedOpacity : 1)
                .animation(reduceMotion ? nil : AnimationTokens.standard, value: breakdown)
            }
        } else {
            LoadingIndicator("Adding up your spending")
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.xxLarge)
        }
    }
}
