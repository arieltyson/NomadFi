import SwiftData
import SwiftUI
import TipKit

/// One category split into finer kinds of spending, such as Flights, Ride
/// Share and Car Share within Transportation, with the merchants behind
/// each. Tapping a merchant sorts it for good.
struct SpendingCategoryView: View {

    let category: TransactionCategory
    let viewModel: SpendingViewModel

    @AppStorage(SpendingChartStyle.storageKey) private var chartStyle = SpendingChartStyle.wheel
    @State private var selectedID: String?
    @State private var expandedIDs: Set<String> = []

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let breakdown = viewModel.breakdown, let slice = breakdown.slice(for: category) {
                let slices = SpendingViewModel.subcategorySlices(of: slice)
                ScrollView {
                    VStack(spacing: SpacingTokens.large) {
                        SpendingChart(
                            slices: slices,
                            total: slice.total,
                            currency: breakdown.currency,
                            caption: String(localized: breakdown.period.title),
                            style: chartStyle,
                            selectedID: $selectedID
                        )

                        if slice.subcategories.contains(where: \.isOther) {
                            TipView(SortMerchantTip())
                                .tipBackground(ColorTokens.surfaceSecondary)
                        }

                        SurfaceCard {
                            VStack(spacing: .zero) {
                                ForEach(Array(zip(slices, slice.subcategories)), id: \.0.id) { chartSlice, subcategory in
                                    SpendingSubcategorySection(
                                        slice: chartSlice,
                                        subcategory: subcategory,
                                        currency: breakdown.currency,
                                        choices: viewModel.choices(for: category),
                                        isHighlighted: chartSlice.id == selectedID,
                                        isExpanded: expansion(for: chartSlice.id)
                                    ) { merchantKey, subcategoryID in
                                        Task {
                                            await viewModel.assign(
                                                merchantKey: merchantKey,
                                                to: subcategoryID,
                                                in: modelContext.container
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(SpacingTokens.medium)
                    .animation(reduceMotion ? nil : AnimationTokens.standard, value: slice)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView(
                    "No \(category.displayName) Spending",
                    systemImage: category.systemImage,
                    description: Text("Purchases from this period will appear here.")
                )
            }
        }
        .navigationTitle(category.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SpendingChartStyleButton(style: $chartStyle)
            }
        }
    }

    private func expansion(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedIDs.contains(id) },
            set: { isExpanded in
                if isExpanded { expandedIDs.insert(id) } else { expandedIDs.remove(id) }
            }
        )
    }
}
