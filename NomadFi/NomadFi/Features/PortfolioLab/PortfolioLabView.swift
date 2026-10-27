// PortfolioLabView.swift
// NomadFi
//
// Tools → Portfolio Lab: how the cost of converting money changes the
// best mix of funds, and what that would have meant over time.

import Charts
import SwiftData
import SwiftUI

/// An educational what-if, not advice: choose an amount, a way to convert
/// currency and a risk level, and see the optimizer's mix for each way of
/// converting, side by side.
struct PortfolioLabView: View {

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel: PortfolioLabViewModel
    @State private var showsTokenSheet = false

    init(viewModel: PortfolioLabViewModel = PortfolioLabViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    private var runKey: String {
        [viewModel.source.rawValue, String(viewModel.amount), viewModel.conversionID, viewModel.profile.rawValue,
         viewModel.expectation.rawValue, String(viewModel.includesCash), viewModel.homeCurrency?.rawValue ?? "",
         String(viewModel.hasToken)].joined(separator: "|")
    }

    var body: some View {
        Group {
            if viewModel.lacksSupportedCurrency {
                ContentUnavailableView(
                    "Portfolio Lab Needs CAD or USD",
                    systemImage: "chart.pie",
                    description: Text("The published exchange-rate history covers Canadian and US dollars. Add a jurisdiction that uses one of them in Settings.")
                )
            } else {
                PortfolioLabForm(viewModel: viewModel, showsTokenSheet: $showsTokenSheet)
            }
        }
        .navigationTitle("Portfolio Lab")
        .sheet(isPresented: $showsTokenSheet) {
            NavigationStack {
                PortfolioLabTokenView(viewModel: viewModel)
            }
        }
        .task(id: jurisdictions.map(\.currencyCodeRawValue)) {
            viewModel.setJurisdictions(jurisdictions)
        }
        .task(id: runKey) {
            // Typing an amount re-runs only once the person pauses.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await viewModel.run()
        }
    }
}

/// The choices, the suggested mix, the conversion comparison and the history.
private struct PortfolioLabForm: View {

    @Bindable var viewModel: PortfolioLabViewModel
    @Binding var showsTokenSheet: Bool

    private var currency: String { viewModel.homeCurrency?.rawValue ?? "CAD" }

    var body: some View {
        Form {
            Section {
                if viewModel.investableCurrencies.count > 1 {
                    Picker("Invest from", selection: $viewModel.homeCurrency) {
                        ForEach(viewModel.investableCurrencies) { code in
                            Text(code.displayName).tag(Optional(code))
                        }
                    }
                }
                TextField("Amount", value: $viewModel.amount, format: .currency(code: currency))
                    .keyboardType(.decimalPad)
                Picker("Convert with", selection: $viewModel.conversionID) {
                    ForEach(viewModel.conversionMethods) { method in
                        Text(method.name).tag(method.id)
                    }
                }
                Picker("Risk", selection: $viewModel.profile) {
                    ForEach(PortfolioLabRiskProfile.allCases, id: \.self) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Expected returns", selection: $viewModel.expectation) {
                    ForEach(PortfolioLabExpectation.allCases, id: \.self) { expectation in
                        Text(expectation.title).tag(expectation)
                    }
                }
                Toggle("Allow cash at 2%", isOn: $viewModel.includesCash)
            } header: {
                Text("Your What-If")
            } footer: {
                Text(viewModel.expectation.explanation)
            }

            PortfolioLabSourceSection(viewModel: viewModel, showsTokenSheet: $showsTokenSheet)

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                    if viewModel.source == .live, !viewModel.hasToken {
                        Button("Add Tiingo Token") { showsTokenSheet = true }
                    }
                }
            } else if viewModel.isRunning {
                Section { LoadingIndicator("Optimizing") }
            } else if let result = viewModel.result {
                PortfolioLabMixSection(result: result, currency: currency)
                PortfolioLabComparisonSection(result: result, currency: currency)
                PortfolioLabHistorySection(scenario: result.selected, currency: currency, isSample: viewModel.source == .sample)
                if !result.issues.isEmpty {
                    PortfolioLabIssuesSection(issues: result.issues)
                }
            }

            PortfolioLabCreditsSection(viewModel: viewModel)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Data source

private struct PortfolioLabSourceSection: View {

    @Bindable var viewModel: PortfolioLabViewModel
    @Binding var showsTokenSheet: Bool

    var body: some View {
        Section {
            Picker("Prices", selection: $viewModel.source) {
                Text("Sample").tag(PortfolioLabDataSource.sample)
                Text("Real (Tiingo)").tag(PortfolioLabDataSource.live)
            }
            .pickerStyle(.segmented)
            Button(viewModel.hasToken ? "Manage Tiingo Token" : "Add Tiingo Token") { showsTokenSheet = true }
        } header: {
            Text("Prices")
        } footer: {
            if viewModel.source == .sample {
                Text(viewModel.sampleNote ?? "Illustrative prices.")
            } else {
                Text("Real month-end prices for US-listed funds, fetched on this iPhone with your own free Tiingo token. Your amounts never leave the device.")
            }
        }
    }
}

// MARK: - Suggested mix

private struct PortfolioLabMixSection: View {

    let result: PortfolioLabResult
    let currency: String

    var body: some View {
        Section {
            ForEach(Array(zip(result.assets, result.selected.weights)), id: \.0.symbol) { asset, weight in
                if weight > 0.0005 {
                    LabeledContent {
                        Text(weight, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    } label: {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxxSmall) {
                            Text(asset.symbol).font(.headline)
                            Text("\(asset.name) · \(asset.currency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(asset.name), \(asset.symbol), in \(asset.currency)")
                    .accessibilityValue(weight.formatted(.percent.precision(.fractionLength(0))))
                }
            }
            LabeledContent("Converted out of \(currency)") {
                Text(result.selected.foreignShare, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            LabeledContent("Expected return · risk") {
                Text("\(result.selected.expectedReturn.formatted(.percent.precision(.fractionLength(1)))) · \(result.selected.expectedVolatility.formatted(.percent.precision(.fractionLength(1))))")
                    .monospacedDigit()
            }
        } header: {
            Text("Optimized Mix with \(result.selected.conversion.name)")
        } footer: {
            Text("The optimizer weighs each fund's expected return against its risk and the cost of getting into it. Converting currency is a cost, so expensive conversion keeps more money at home.")
        }
    }
}

// MARK: - Conversion comparison

private struct PortfolioLabComparisonSection: View {

    let result: PortfolioLabResult
    let currency: String

    private var bestEndingValue: Double {
        result.comparisons.map(\.backtest.endingValue).max() ?? 0
    }

    var body: some View {
        Section {
            ForEach(result.comparisons, id: \.conversion.id) { scenario in
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    HStack {
                        Text(scenario.conversion.name).font(.headline)
                        if scenario.backtest.endingValue == bestEndingValue {
                            StatusBadge(label: String(localized: "Best"), color: ColorTokens.positive, systemImage: "checkmark")
                        }
                    }
                    Text("Converts \(scenario.foreignShare.formatted(.percent.precision(.fractionLength(0)))) · costs \(scenario.backtest.initialCost.formatted(.currency(code: currency))) up front")
                        .font(.subheadline)
                    Text("Would be \(scenario.backtest.endingValue.formatted(.currency(code: currency).precision(.fractionLength(0)))) after \(result.months.count / 12) years, all costs paid")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Ways to Convert")
        } footer: {
            Text("Each row is optimized separately, because the cost of converting changes which mix is best. Rates are typical published retail costs, not quotes: check your own bank and brokerage.")
        }
    }
}

// MARK: - History

private struct PortfolioLabHistorySection: View {

    let scenario: PortfolioLabScenario
    let currency: String
    let isSample: Bool

    @State private var showsValues = false

    private var points: [(date: Date, value: Double)] {
        scenario.backtest.points.compactMap { point in
            guard let date = Self.monthFormat.date(from: point.month) else { return nil }
            return (date, point.value)
        }
    }

    private static let monthFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    var body: some View {
        Section {
            Chart(points, id: \.date) { point in
                LineMark(x: .value("Month", point.date), y: .value("Value", point.value))
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
            .chartYAxis { AxisMarks(format: .currency(code: currency).precision(.fractionLength(0))) }
            .frame(minHeight: 180)
            .accessibilityHidden(true)

            LabeledContent("Yearly return") {
                Text(scenario.backtest.annualReturn, format: .percent.precision(.fractionLength(1))).monospacedDigit()
            }
            LabeledContent("Worst drop") {
                Text(scenario.backtest.maxDrawdown, format: .percent.precision(.fractionLength(1))).monospacedDigit()
            }
            LabeledContent("Costs paid, including rebalancing") {
                Text(scenario.backtest.totalCost, format: .currency(code: currency)).monospacedDigit()
            }
            DisclosureGroup("Values by Month", isExpanded: $showsValues) {
                ForEach(scenario.backtest.points, id: \.month) { point in
                    LabeledContent(point.month) {
                        Text(point.value, format: .currency(code: currency).precision(.fractionLength(0))).monospacedDigit()
                    }
                }
            }
        } header: {
            Text(isSample ? "Illustrative History" : "Past Performance")
        } footer: {
            Text("Invested once at the start and rebalanced yearly. Past results, real or illustrative, don't predict future returns.")
        }
    }
}

// MARK: - Data checks

private struct PortfolioLabIssuesSection: View {

    let issues: [PortfolioLabDataIssue]

    var body: some View {
        Section {
            ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                LabeledContent("\(issue.symbol) · \(issue.month)") {
                    Text(issue.kind.title)
                }
            }
        } header: {
            Text("Data Checks")
        } footer: {
            Text("Flagged months are left out of the calculation rather than guessed.")
        }
    }
}

// MARK: - Credits

private struct PortfolioLabCreditsSection: View {

    let viewModel: PortfolioLabViewModel

    var body: some View {
        Section {
            if let snapshot = viewModel.snapshot {
                Text(snapshot.source.attribution)
                    .font(.footnote)
                Link("Bank of Canada exchange rates", destination: snapshot.source.url)
                    .font(.footnote)
            }
            if viewModel.source == .live {
                Link("Data sourced by Tiingo", destination: TiingoPriceService.attributionURL)
                    .font(.footnote)
            }
        } footer: {
            Text("Portfolio Lab is for learning how costs and risk interact. It isn't investment advice or a recommendation to buy any fund.")
        }
    }
}

// MARK: - Labels

extension PortfolioLabRiskProfile {
    var title: LocalizedStringKey {
        switch self {
        case .cautious: "Cautious"
        case .balanced: "Balanced"
        case .growth: "Growth"
        }
    }
}

extension PortfolioLabExpectation {
    var title: LocalizedStringKey {
        switch self {
        case .shrunkHistorical: "From history"
        case .equal: "Same for all"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .shrunkHistorical: "Each fund's past average, pulled halfway toward the average of all funds so no single good run dominates."
        case .equal: "Every fund is assumed to earn the same, so the mix only balances risk against conversion costs."
        }
    }
}

extension PortfolioLabIssueKind {
    var title: LocalizedStringKey {
        switch self {
        case .duplicate: "Duplicate month"
        case .missing: "Missing month"
        case .nonpositive: "Unusable price"
        case .jump: "Unusual jump"
        case .stale: "Price stopped updating"
        case .unreadableMonth: "Unreadable date"
        }
    }
}

#Preview {
    NavigationStack {
        PortfolioLabView(viewModel: PortfolioLabViewModel(priceService: MockPortfolioLabPriceService()))
    }
    .modelContainer(for: JurisdictionProfile.self, inMemory: true)
}
