// ScenarioDecisionBriefView.swift
// NomadFi
//
// Detail sheet for Scenario 1 — Amazon.com arrival order. Numeric inputs
// (Chase available credit, Chase current balance, statement close date,
// Wise USD balance) are persisted in the underlying `ScenarioDecisionRecord`
// via SwiftData; the pure engine re-runs on every edit.

import SwiftUI

/// The detail sheet for Scenario 1. Presented from the Dashboard card.
struct ScenarioDecisionBriefView: View {

    @Bindable var viewModel: ScenarioDecisionBriefViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.large) {
                    rulingSection
                    beforeCheckoutSection
                    computedValuesSection
                    costBreakdownSection
                    paymentOptionsSection
                    chaseGuardrailSection
                    hardRulesSection
                    outstandingChecksSection
                    sourcesSection
                }
                .padding(SpacingTokens.medium)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Amazon arrival order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: { dismiss() })
                }
            }
        }
    }
}

// MARK: - Sections

private extension ScenarioDecisionBriefView {

    var decision: ScenarioDecision {
        viewModel.decision
    }

    var rulingSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Ruling", systemImage: "scale.3d")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Text(decision.ruling)
                    .font(TypographyTokens.body)
                    .fixedSize(horizontal: false, vertical: true)

                if !decision.rationale.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        ForEach(Array(decision.rationale.enumerated()), id: \.offset) { _, line in
                            bulletedLine(line)
                        }
                    }
                }

                HStack(spacing: SpacingTokens.xxSmall) {
                    ScenarioEvidenceBadge(tag: .screenshotFact)
                    ScenarioEvidenceBadge(tag: .inference)
                    ScenarioEvidenceBadge(tag: .needsUserInput)
                }
                .accessibilityHidden(true)
            }
        }
    }

    var beforeCheckoutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Before checkout", systemImage: "checklist")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Text("Enter the real numbers from Chase and Wise. Values are stored only on this device and can be wiped from Settings → Privacy.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                cartAndArrivalInputs
                chaseInputs
                wiseInputs
            }
        }
    }

    var cartAndArrivalInputs: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Toggle(
                "Cart reviewed — shipping and Subscribe & Save",
                isOn: binding(\.cartShippingReviewed)
            )
            Toggle(
                "Airbnb host can receive the package (or delivery timed for the U.S. summer address after arrival)",
                isOn: binding(\.airbnbPackageReceiptConfirmed)
            )
        }
    }

    var chaseInputs: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Label("Chase Freedom Rise", systemImage: "creditcard.fill")
                .font(TypographyTokens.sectionHeader.weight(.regular))
                .foregroundStyle(.secondary)

            ScenarioNumericInputRow(
                title: "Available credit",
                helper: "Open Chase, read available credit, and enter it here — USD.",
                placeholder: "USD",
                systemImage: "creditcard",
                value: binding(\.chaseAvailableCreditUSD)
            )
            ScenarioNumericInputRow(
                title: "Current statement balance",
                helper: "Today's Chase balance, not the last statement — USD.",
                placeholder: "USD",
                systemImage: "dollarsign.circle",
                value: binding(\.chaseCurrentBalanceUSD)
            )
            DatePicker(
                "Statement close date",
                selection: Binding(
                    get: { viewModel.record.chaseStatementCloseDate ?? .now },
                    set: { newValue in
                        viewModel.record.chaseStatementCloseDate = newValue
                        viewModel.markEdited()
                    }
                ),
                displayedComponents: .date
            )
            Toggle(
                "I will pay before statement close",
                isOn: binding(\.chaseWillPayBeforeStatementClose)
            )
        }
    }

    var wiseInputs: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Label("Wise", systemImage: "building.columns.fill")
                .font(TypographyTokens.sectionHeader.weight(.regular))
                .foregroundStyle(.secondary)

            ScenarioNumericInputRow(
                title: "Wise USD balance",
                helper: "From the Wise app — the amount held in the USD jar.",
                placeholder: "USD",
                systemImage: "wallet.pass.fill",
                value: binding(\.wiseUSDBalanceUSD)
            )
            Toggle(
                "Wise card accepted by Amazon",
                isOn: binding(\.wiseCardAcceptedByAmazon)
            )
        }
    }

    var computedValuesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                Label("From your numbers", systemImage: "function")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                computedRow(
                    label: "Projected Chase utilization",
                    value: projectedUtilizationValue,
                    tag: .inference,
                    note: projectedUtilizationNote
                )
                computedRow(
                    label: "Chase available credit vs. checkout + buffer",
                    value: chaseCoverageValue,
                    tag: .inference,
                    note: "Threshold is USD \(decision.computedValues.chaseRequiredAvailableCreditUSD.formatted(.number.precision(.fractionLength(2)))) (USD \(decision.computedValues.chaseAvailableCreditSafetyBufferUSD.formatted(.number.precision(.fractionLength(0)))) safety buffer on USD \(decision.computedValues.checkoutAmountUSD.formatted(.number.precision(.fractionLength(2)))) checkout)."
                )
                computedRow(
                    label: "Wise USD balance covers checkout",
                    value: wiseCoverageValue,
                    tag: .inference,
                    note: nil
                )
                computedRow(
                    label: "Current recommended path",
                    value: recommendedPathLabel,
                    tag: .inference,
                    note: nil
                )
            }
        }
    }

    var costBreakdownSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Label("Cost breakdown", systemImage: "number")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                ForEach(decision.costBreakdown) { line in
                    costRow(line)
                }
            }
        }
    }

    var paymentOptionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Label("Payment options", systemImage: "creditcard.and.123")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            ForEach(decision.paymentOptions) { option in
                ScenarioPaymentOptionRow(option: option)
            }
        }
    }

    var chaseGuardrailSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                Label("Chase utilization guardrail", systemImage: "shield.checkered")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                Text("Chase Freedom Rise is only recommended when your entered available credit clears checkout + a safety buffer, your current balance is known, and you commit to paying before statement close. Without all four, this tool routes to Wise USD or blocks on user input.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var hardRulesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                Label("Hard rules", systemImage: "exclamationmark.shield")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                ForEach(Array(decision.hardRules.enumerated()), id: \.offset) { _, rule in
                    bulletedLine(rule)
                }
            }
        }
    }

    var outstandingChecksSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                Label("Evidence and assumptions", systemImage: "doc.text.magnifyingglass")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                if decision.outstandingChecks.isEmpty {
                    Text("All user-side checks are confirmed.")
                        .font(TypographyTokens.body)
                } else {
                    ForEach(Array(decision.outstandingChecks.enumerated()), id: \.offset) { _, check in
                        HStack(alignment: .top, spacing: SpacingTokens.xxSmall) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(ColorTokens.warning)
                                .accessibilityHidden(true)
                            Text(check)
                                .font(TypographyTokens.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    var sourcesSection: some View {
        ScenarioSourcesList(citations: decision.citations)
    }

    // MARK: - Bindings

    /// Creates a binding to a record property that also stamps
    /// `updatedAt` on every write.
    func binding<Value>(
        _ keyPath: ReferenceWritableKeyPath<ScenarioDecisionRecord, Value>
    ) -> Binding<Value> {
        Binding(
            get: { viewModel.record[keyPath: keyPath] },
            set: { newValue in
                viewModel.record[keyPath: keyPath] = newValue
                viewModel.markEdited()
            }
        )
    }

    // MARK: - Derived text

    var projectedUtilizationValue: String {
        guard let percent = decision.computedValues.projectedChaseUtilizationPercent else {
            return "Needs current balance"
        }
        return "≈ \((percent * 100).formatted(.number.precision(.fractionLength(1))))%"
    }

    var projectedUtilizationNote: String? {
        guard let balance = decision.computedValues.projectedChaseBalanceUSD else {
            return "Enter the Chase current balance to see the projection."
        }
        return "USD \(balance.formatted(.number.precision(.fractionLength(2)))) projected against a USD \(decision.computedValues.checkoutAmountUSD.formatted(.number.precision(.fractionLength(2)))) checkout. Zero-balance reference: ≈ \(zeroBalanceReferenceText)."
    }

    var zeroBalanceReferenceText: String {
        guard let zero = decision.computedValues.zeroBalanceChaseUtilizationPercent else {
            return "unknown"
        }
        return "\((zero * 100).formatted(.number.precision(.fractionLength(1))))%"
    }

    var chaseCoverageValue: String {
        switch decision.computedValues.chaseHasSufficientAvailableCredit {
        case .some(true): "Covers with buffer"
        case .some(false): "Short of threshold"
        case .none: "Needs available credit"
        }
    }

    var wiseCoverageValue: String {
        switch decision.computedValues.wiseBalanceCoversCheckout {
        case .some(true): "Covers checkout"
        case .some(false): "Below checkout"
        case .none: "Needs Wise USD balance"
        }
    }

    var recommendedPathLabel: String {
        switch decision.primaryPath {
        case .reviewCartFirst: "Review cart first"
        case .chaseFreedomRiseUSD: "Chase Freedom Rise (USD)"
        case .wiseUSD: "Wise USD"
        case .awaitingUserInput: "Awaiting inputs"
        }
    }

    @ViewBuilder
    func bulletedLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xxSmall) {
            Text("\u{2022}")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func costRow(_ line: ScenarioCostLine) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.label)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                Spacer(minLength: SpacingTokens.xSmall)
                Text(line.value)
                    .font(TypographyTokens.body)
                    .monospacedDigit()
            }
            HStack(spacing: SpacingTokens.xxSmall) {
                ScenarioEvidenceBadge(tag: line.evidence)
                if let note = line.note {
                    Text(note)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    func computedRow(
        label: String,
        value: String,
        tag: ScenarioEvidenceTag,
        note: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: SpacingTokens.xSmall)
                Text(value)
                    .font(TypographyTokens.body)
                    .monospacedDigit()
            }
            HStack(spacing: SpacingTokens.xxSmall) {
                ScenarioEvidenceBadge(tag: tag)
                if let note {
                    Text(note)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    ScenarioDecisionBriefView(
        viewModel: ScenarioDecisionBriefViewModel()
    )
}
