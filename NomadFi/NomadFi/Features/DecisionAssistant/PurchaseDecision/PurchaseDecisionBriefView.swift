// PurchaseDecisionBriefView.swift
// NomadFi
//
// Detail sheet for the generic purchase decision. Composes:
//
//   1. A capture form (merchant / category / amount / currency /
//      location / timing) bound through ``PurchaseDecisionBriefViewModel``.
//   2. A top-level ruling header that summarises the engine output.
//   3. Candidate rows (recommendation, fallback, caveated, blocked).
//   4. Missing-data checklist.
//   5. Hard rules.
//   6. Cited sources.
//
// Reuses the same Decision Assistant visual language as the Credit
// Timing brief (`ScrollView { LazyVStack { GlassCard … } }`), with
// the design-system `.keyboardDoneAccessory(focused:)` modifier
// for the `.decimalPad` amount field.

import SwiftData
import SwiftUI

/// Brief sheet for the generic purchase decision.
struct PurchaseDecisionBriefView: View {

    let accounts: [Account]

    @Bindable var viewModel: PurchaseDecisionBriefViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private var decision: PurchaseDecision {
        viewModel.decision(accounts: accounts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: SpacingTokens.large
                ) {
                    captureFormSection
                    rulingSection
                    confidenceSection
                    travelContextSection
                    recommendationSection
                    fallbackSection
                    otherCandidatesSection
                    checklistSection
                    warningsSection
                    hardRulesSection
                    sourcesSection
                    evaluatedAtNote
                }
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.medium)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Purchase card check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .keyboardDoneAccessory(focused: $focusedField)
        }
    }

    // MARK: - Capture form

    private var captureFormSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Purchase details")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    TextField(
                        "Merchant (optional)",
                        text: Binding(
                            get: { viewModel.record.merchantName },
                            set: { viewModel.record.merchantName = $0 }
                        )
                    )
                    .textFieldStyle(.nomadFi)
                    .focused($focusedField, equals: .merchant)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel("Merchant")
                    .accessibilityHint("Merchant or counterparty you expect to pay. Optional.")

                    Picker(
                        "Category",
                        selection: Binding(
                            get: { viewModel.record.category },
                            set: { viewModel.setCategory($0) }
                        )
                    ) {
                        ForEach(MerchantCategory.allCases, id: \.self) { category in
                            Label(category.displayLabel, systemImage: category.systemImage)
                                .tag(category)
                                .accessibilityLabel(category.accessibilityLabel)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack(spacing: SpacingTokens.small) {
                        TextField(
                            "Amount",
                            text: Binding(
                                get: { viewModel.amountText },
                                set: { viewModel.amountText = $0 }
                            )
                        )
                        .textFieldStyle(.nomadFi)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .accessibilityLabel("Amount")
                        .onChange(of: viewModel.amountText) { _, _ in
                            viewModel.commitAmountEdit()
                        }

                        Picker(
                            "Currency",
                            selection: Binding(
                                get: { viewModel.record.currencyCode },
                                set: { viewModel.setCurrencyCode($0) }
                            )
                        ) {
                            ForEach(CurrencyCode.allCases) { code in
                                Text(code.rawValue).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityLabel("Purchase currency")
                    }

                    TextField(
                        "City or short location hint (optional)",
                        text: Binding(
                            get: { viewModel.record.countryCode },
                            set: { viewModel.record.countryCode = $0 }
                        )
                    )
                    .textFieldStyle(.nomadFi)
                    .focused($focusedField, equals: .country)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel("City or short location hint")
                    .accessibilityHint("A short hint like a city name. Don't enter a full street address.")

                    TextField(
                        "Timing (optional)",
                        text: Binding(
                            get: { viewModel.record.timingText },
                            set: { viewModel.record.timingText = $0 }
                        )
                    )
                    .textFieldStyle(.nomadFi)
                    .focused($focusedField, equals: .timing)
                    .submitLabel(.done)
                    .accessibilityLabel("Timing note")

                    Text("Don't enter card numbers, account numbers, or full addresses. The engine doesn't need them.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Ruling

    private var rulingSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                    Image(systemName: "creditcard.and.123")
                        .font(.title)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("Current ruling")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)

                        Text(decision.ruling.displaySummary)
                            .font(TypographyTokens.sectionHeader)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: SpacingTokens.xxSmall) {
                    StatusBadge(
                        label: "\(decision.candidateCount) account\(decision.candidateCount == 1 ? "" : "s")",
                        color: ColorTokens.neutral,
                        systemImage: "rectangle.stack"
                    )
                    if decision.outstandingCheckCount > 0 {
                        StatusBadge(
                            label: "\(decision.outstandingCheckCount) check\(decision.outstandingCheckCount == 1 ? "" : "s")",
                            color: ColorTokens.warning,
                            systemImage: "questionmark.circle.fill"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Confidence (Phase 3 follow-through)

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Confidence")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                        Image(systemName: decision.confidence.systemImage)
                            .font(.title3)
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .frame(width: 28, alignment: .center)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            Text(decision.confidence.displayLabel)
                                .font(TypographyTokens.body)
                                .bold()
                                .accessibilityAddTraits(.isHeader)
                            Text(decision.confidence.summary)
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    if !decision.confidenceExplanations.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                            ForEach(decision.confidenceExplanations, id: \.self) { note in
                                Label {
                                    Text(note)
                                        .font(TypographyTokens.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                } icon: {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(ColorTokens.brandPrimary)
                                        .accessibilityHidden(true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Travel context (Phase 3 follow-through)

    @ViewBuilder
    private var travelContextSection: some View {
        if decision.travelContext.isLikelyCrossBorder {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text("Cross-border context")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                GlassCard {
                    VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                        ForEach(travelContextSignals, id: \.self) { line in
                            Label {
                                Text(line)
                                    .font(TypographyTokens.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "globe")
                                    .foregroundStyle(ColorTokens.brandPrimary)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private var travelContextSignals: [String] {
        var signals: [String] = []
        if decision.travelContext.isCrossCurrency {
            signals.append("At least one of your saved accounts is in a different currency from this purchase.")
        }
        if decision.travelContext.hasLocationHint {
            signals.append("You typed a location hint, so cross-border DCC and dispute caveats apply.")
        }
        if decision.travelContext.isTravelCategory {
            signals.append("Travel category — card acceptance and fallback are part of the picture.")
        }
        return signals
    }

    // MARK: - Recommendation

    @ViewBuilder
    private var recommendationSection: some View {
        if let recommendation = decision.recommendation {
            PurchaseDecisionHighlightSection(
                title: "Recommended",
                assessment: recommendation,
                badgeColor: ColorTokens.positive
            )
        }
    }

    @ViewBuilder
    private var fallbackSection: some View {
        if let fallback = decision.fallback {
            PurchaseDecisionHighlightSection(
                title: "Fallback",
                assessment: fallback,
                badgeColor: ColorTokens.neutral
            )
        }
    }

    // MARK: - Other candidates

    @ViewBuilder
    private var otherCandidatesSection: some View {
        let others = decision.candidates.filter {
            $0.stance != .recommended && $0.stance != .fallback
        }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text("Other accounts")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: SpacingTokens.xSmall) {
                    ForEach(others) { candidate in
                        GlassCard {
                            PurchaseCandidateRow(assessment: candidate)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Checklist

    @ViewBuilder
    private var checklistSection: some View {
        if !decision.missingDataChecklist.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text("Missing data")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                GlassCard {
                    VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                        ForEach(decision.missingDataChecklist, id: \.self) { item in
                            Label {
                                Text(item)
                                    .font(TypographyTokens.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(ColorTokens.warning)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningsSection: some View {
        if !decision.whenNotToUseWarnings.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text("When not to use these")
                    .font(TypographyTokens.sectionHeader)
                    .accessibilityAddTraits(.isHeader)

                GlassCard {
                    VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                        ForEach(decision.whenNotToUseWarnings, id: \.self) { item in
                            Label {
                                Text(item)
                                    .font(TypographyTokens.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(ColorTokens.warning)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hard rules

    private var hardRulesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Hard rules")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    ForEach(decision.hardRules, id: \.self) { rule in
                        Label {
                            Text(rule)
                                .font(TypographyTokens.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(ColorTokens.brandPrimary)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Sources")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(decision.citations) { citation in
                    Link(destination: citation.url) {
                        GlassCard {
                            PurchaseDecisionSourceRow(citation: citation)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the official source in your browser.")
                }
            }
        }
    }

    private var evaluatedAtNote: some View {
        Text("Evaluated \(decision.evaluatedAt.formatted(.dateTime.year().month(.wide).day().hour().minute()))")
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Evaluated as of \(decision.evaluatedAt.formatted(.dateTime.year().month(.wide).day().hour().minute()))")
    }
}

// MARK: - Focus fields

private extension PurchaseDecisionBriefView {

    enum Field: Hashable {
        case merchant
        case amount
        case country
        case timing
    }
}

// MARK: - Highlight section (recommended / fallback)

private struct PurchaseDecisionHighlightSection: View {

    let title: String
    let assessment: PurchaseCandidateAssessment
    let badgeColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                PurchaseCandidateRow(
                    assessment: assessment,
                    highlightBadgeColor: badgeColor
                )
            }
        }
    }
}

// MARK: - Candidate row

private struct PurchaseCandidateRow: View {

    let assessment: PurchaseCandidateAssessment
    var highlightBadgeColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            header

            if !assessment.reasons.isEmpty {
                PurchaseCandidateNotes(items: assessment.reasons, icon: "info.circle")
            }

            PurchaseCandidateMetrics(assessment: assessment)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: assessment.stance.systemImage)
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(assessment.accountName)
                    .font(TypographyTokens.body)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)

                let subtitle = [
                    assessment.institutionName,
                    assessment.accountTypeDisplay,
                    assessment.currencyCode,
                ]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SpacingTokens.xSmall)

            StatusBadge(
                label: assessment.stance.displayLabel,
                color: highlightBadgeColor ?? badgeColor(for: assessment.stance),
                systemImage: assessment.stance.systemImage
            )
            .accessibilityLabel(assessment.stance.accessibilityLabel)
        }
    }

    private func badgeColor(
        for stance: PurchaseCandidateStance
    ) -> Color {
        switch stance {
        case .recommended: ColorTokens.positive
        case .fallback: ColorTokens.neutral
        case .usableWithCaveats: ColorTokens.warning
        case .insufficientFunds,
             .insufficientCreditCoverage: ColorTokens.negative
        case .snapshotStale,
             .needsSetup,
             .excludedInvestment: ColorTokens.neutral
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = [
            assessment.accountName,
            assessment.stance.accessibilityLabel,
        ]
        if !assessment.matchesPurchaseCurrency {
            parts.append("Currency does not match the purchase currency.")
        }
        if let limit = assessment.creditLimit {
            parts.append("Credit limit \(limit.formatted(.currency(code: assessment.currencyCode))).")
        }
        if let available = assessment.availableCredit {
            parts.append("Available credit \(available.formatted(.currency(code: assessment.currencyCode))).")
        }
        if let balance = assessment.currentBalance {
            parts.append("Current balance \(balance.formatted(.currency(code: assessment.currencyCode))).")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Notes and metrics

private struct PurchaseCandidateNotes: View {

    let items: [String]
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct PurchaseCandidateMetrics: View {

    let assessment: PurchaseCandidateAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            if let limit = assessment.creditLimit {
                metricLine(
                    label: "Credit limit",
                    value: limit.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let available = assessment.availableCredit {
                metricLine(
                    label: "Available credit",
                    value: available.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let balance = assessment.currentBalance, !assessment.isCreditCard {
                metricLine(
                    label: "Current balance",
                    value: balance.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let feePercent = assessment.foreignTransactionFeePercent {
                let formatted = feePercent.formatted(
                    .number.precision(.fractionLength(1))
                )
                metricLine(
                    label: "Foreign-transaction fee",
                    value: assessment.foreignTransactionFeeIsVerified
                        ? "\(formatted)%"
                        : "\(formatted)% · needs verification"
                )
            }
        }
    }

    private func metricLine(
        label: String,
        value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: SpacingTokens.small)
            Text(value)
                .font(TypographyTokens.body)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Source row

private struct PurchaseDecisionSourceRow: View {

    let citation: ScenarioCitation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: citation.evidence.systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(citation.title)
                    .font(TypographyTokens.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text(citation.publisher)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                Text(citation.summary)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(citation.title), \(citation.publisher). \(citation.summary)")
    }
}

#Preview {
    let record = PurchaseDecisionRecord(
        scenarioID: PurchaseDecisionRecord.activeRecordID,
        merchantName: "Target",
        category: .groceries,
        amount: 75,
        currencyCode: .usd,
        countryCode: "San Francisco",
        timingText: "This weekend"
    )
    let vm = PurchaseDecisionBriefViewModel(record: record)
    return PurchaseDecisionBriefView(
        accounts: [],
        viewModel: vm
    )
    .modelContainer(
        for: [Account.self, PurchaseDecisionRecord.self],
        inMemory: true
    )
}
