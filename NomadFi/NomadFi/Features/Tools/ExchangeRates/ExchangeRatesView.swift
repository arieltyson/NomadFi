// ExchangeRatesView.swift
// NomadFi
//
// Tools → Exchange Rates: the rates between the person's currencies.

import SwiftData
import SwiftUI

/// The rates between the person's currencies, one native row per pair.
///
/// How far to trust them — source confidence and freshness — is one
/// quiet footer line rather than badges on every row.
struct ExchangeRatesView: View {

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel = ExchangeRatesViewModel()

    private var currencies: [CurrencyCode] {
        ExchangeRatesViewModel.currencies(from: jurisdictions)
    }

    var body: some View {
        Group {
            if currencies.count < 2 {
                ContentUnavailableView(
                    "No Currency Pairs",
                    systemImage: "dollarsign.arrow.circlepath",
                    description: Text("Add a jurisdiction with another currency in Settings.")
                )
            } else if viewModel.isLoading {
                LoadingIndicator("Loading rates")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("Rates Unavailable", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.load(for: currencies, force: true) }
                    }
                }
            } else {
                ExchangeRateList(viewModel: viewModel)
            }
        }
        .navigationTitle("Exchange Rates")
        .refreshable { await viewModel.load(for: currencies, force: true) }
        .task(id: currencies) { await viewModel.load(for: currencies) }
    }
}

/// The rate rows and their trust footer.
private struct ExchangeRateList: View {

    let viewModel: ExchangeRatesViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.rates) { rate in
                    LabeledContent("\(rate.baseCurrency.rawValue) → \(rate.targetCurrency.rawValue)") {
                        Text(rate.rate, format: .number.precision(.fractionLength(2...4)))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "1 \(rate.baseCurrency.displayName) equals \(rate.rate.formatted(.number.precision(.fractionLength(2...4)))) \(rate.targetCurrency.displayName)"
                    )
                }
            } footer: {
                ExchangeRateFooter(viewModel: viewModel)
            }
        }
    }
}

/// "Indicative · Updated 3:41 PM" (or a note when rates are stale),
/// and the credit the rate provider's free terms require.
private struct ExchangeRateFooter: View {

    let viewModel: ExchangeRatesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            if let confidence = viewModel.confidence, let lastUpdated = viewModel.lastUpdated {
                if viewModel.needsRefresh {
                    Text("\(confidence.displayLabel) · Needs refresh")
                } else {
                    Text("\(confidence.displayLabel) · Updated \(lastUpdated, format: .dateTime.hour().minute())")
                }
            }

            if let attribution = ExchangeRatesViewModel.attributionURL {
                Link("Rates by Exchange Rate API", destination: attribution)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExchangeRatesView()
    }
    .modelContainer(for: JurisdictionProfile.self, inMemory: true)
}
