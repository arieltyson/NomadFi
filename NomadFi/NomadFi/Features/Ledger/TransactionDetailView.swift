import SwiftData
import SwiftUI
import TipKit

/// A detailed view for a single transaction showing amounts, FX analysis,
/// category, and tax relevance controls.
///
/// For cross-border transactions, includes the Real Cost analysis card
/// comparing the applied rate against the mid-market rate.
struct TransactionDetailView: View {

    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = LedgerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                amountSection

                if isCrossBorder {
                    TipView(RealCostTip())
                        .tipBackground(ColorTokens.surfaceSecondary)

                    realCostSection
                    fxRateSection
                }

                detailsSection

                taxSection
            }
            .padding(SpacingTokens.medium)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(transaction.merchantName)
        .glassToolbar()
    }
}

// MARK: - Amount Section

private struct AmountHeader: View {

    let transaction: Transaction

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            if let currency = transaction.originalCurrency {
                CurrencyText(
                    amount: transaction.originalAmount,
                    currencyCode: currency,
                    font: TypographyTokens.amountLarge
                )
                .bold()
            }

            if transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue,
               transaction.convertedAmount != 0,
               let homeCurrency = transaction.homeCurrency
            {
                CurrencyText(
                    amount: transaction.convertedAmount,
                    currencyCode: homeCurrency,
                    font: TypographyTokens.amountMedium
                )
                .foregroundStyle(.secondary)
            }

            Text(transaction.date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {

    let label: String
    let value: String
    var systemImage: String?

    var body: some View {
        HStack {
            if let systemImage {
                Label(label, systemImage: systemImage)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
            } else {
                Text(label)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(TypographyTokens.body)
        }
    }
}

// MARK: - Private Helpers

private extension TransactionDetailView {

    var isCrossBorder: Bool {
        transaction.originalCurrencyRawValue != transaction.homeCurrencyRawValue
            && transaction.midMarketRate > 0
    }

    var amountSection: some View {
        AmountHeader(transaction: transaction)
    }

    var realCostSection: some View {
        Group {
            let breakdown = viewModel.realCostBreakdown(for: transaction)
            if let homeCurrency = transaction.homeCurrency {
                RealCostCard(
                    fairCost: breakdown.fairCost,
                    actualCost: breakdown.actualCost,
                    delta: breakdown.delta,
                    homeCurrency: homeCurrency
                )
            }
        }
    }

    var fxRateSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Exchange Rate", systemImage: "chart.line.uptrend.xyaxis")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                DetailRow(
                    label: "Applied Rate",
                    value: transaction.appliedExchangeRate.formatted(
                        .number.precision(.fractionLength(2...4))
                    )
                )

                DetailRow(
                    label: "Mid-Market Rate",
                    value: transaction.midMarketRate.formatted(
                        .number.precision(.fractionLength(2...4))
                    )
                )

                if transaction.appliedExchangeRate > 0, transaction.midMarketRate > 0 {
                    let markupPercent = ((transaction.appliedExchangeRate / transaction.midMarketRate) - 1) * 100
                    DetailRow(
                        label: "Markup",
                        value: "\(abs(markupPercent).formatted(.number.precision(.fractionLength(2))))% \(markupDescriptor(for: markupPercent))",
                        systemImage: ColorTokens.fxMarkupIcon(for: markupPercent)
                    )
                    .foregroundStyle(ColorTokens.fxMarkupColor(for: markupPercent))
                }
            }
        }
    }

    var detailsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Details", systemImage: "info.circle")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                if let category = transaction.category {
                    DetailRow(
                        label: "Category",
                        value: category.displayName,
                        systemImage: category.systemImage
                    )
                }

                if !transaction.jurisdiction.isEmpty {
                    DetailRow(
                        label: "Jurisdiction",
                        value: transaction.jurisdiction,
                        systemImage: "mappin.and.ellipse"
                    )
                }

                if let account = transaction.account {
                    DetailRow(
                        label: "Account",
                        value: "\(account.name) (\(account.institutionName))",
                        systemImage: "creditcard"
                    )
                }

                if !transaction.notes.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("Notes")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)

                        Text(transaction.notes)
                            .font(TypographyTokens.body)
                    }
                }
            }
        }
    }

    var taxSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Tax", systemImage: "doc.text")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Toggle("Tax Deductible", isOn: $transaction.isTaxDeductible)
                    .font(TypographyTokens.body)

                if transaction.isTaxDeductible {
                    Label("This transaction will appear in your Tax Vault", systemImage: "checkmark.circle")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.positive)
                }
            }
        }
    }

    func markupDescriptor(for markupPercent: Double) -> String {
        if markupPercent <= 0 {
            return "fair or better"
        } else if markupPercent < 1 {
            return "slight markup"
        } else {
            return "high markup"
        }
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(
            transaction: Transaction(
                merchantName: "Whole Foods Market",
                originalAmount: -67.43,
                originalCurrency: .usd,
                convertedAmount: -457.19,
                homeCurrency: .ttd,
                appliedExchangeRate: 6.78,
                midMarketRate: 6.75,
                date: .now,
                category: .food,
                jurisdiction: "US",
                notes: "Weekly grocery run"
            )
        )
    }
}
