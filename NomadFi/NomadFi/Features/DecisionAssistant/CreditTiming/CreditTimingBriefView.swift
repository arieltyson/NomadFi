// CreditTimingBriefView.swift
// NomadFi
//
// Detail sheet for the Credit Timing decision. Renders the engine's
// full output — top ruling, per-card assessments, missing-data
// checklist, hard rules, and cited sources — without ever claiming a
// credit-score outcome.
//
// Layout uses `ScrollView { LazyVStack }` to match the rest of the
// Decision Assistant's command-center aesthetic and to preserve
// Dynamic Type behaviour across AX sizes.

import SwiftData
import SwiftUI

/// Presents the Credit Timing engine output. The view receives the
/// live `[Account]` list from the parent's `@Query`, re-runs the
/// engine locally, and renders the decision.
struct CreditTimingBriefView: View {

    let accounts: [Account]

    @Environment(\.dismiss) private var dismiss

    private var decision: CreditTimingDecision {
        CreditTimingDecisionEngine.decide(accounts: accounts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: SpacingTokens.large
                ) {
                    CreditTimingRulingHeader(decision: decision)

                    if !decision.cardAssessments.isEmpty {
                        CreditTimingCardsSection(assessments: decision.cardAssessments)
                    }

                    if !decision.missingDataChecklist.isEmpty {
                        CreditTimingChecklistSection(
                            items: decision.missingDataChecklist
                        )
                    }

                    CreditTimingHardRulesSection(rules: decision.hardRules)

                    CreditTimingSourcesSection(citations: decision.citations)

                    CreditTimingEvaluatedAtNote(evaluatedAt: decision.evaluatedAt)
                }
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.medium)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Credit timing check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ruling header

private struct CreditTimingRulingHeader: View {

    let decision: CreditTimingDecision

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
                    Image(systemName: "calendar.badge.clock")
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
                        label: "\(decision.cardCount) card\(decision.cardCount == 1 ? "" : "s")",
                        color: ColorTokens.neutral,
                        systemImage: "creditcard"
                    )
                    if decision.outstandingCheckCount > 0 {
                        StatusBadge(
                            label: "\(decision.outstandingCheckCount) check\(decision.outstandingCheckCount == 1 ? "" : "s")",
                            color: ColorTokens.warning,
                            systemImage: "questionmark.circle.fill"
                        )
                    } else if !decision.cardAssessments.isEmpty {
                        StatusBadge(
                            label: "Ready",
                            color: ColorTokens.positive,
                            systemImage: "checkmark.seal.fill"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Cards section

private struct CreditTimingCardsSection: View {

    let assessments: [CreditTimingCardAssessment]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Per-card assessment")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(assessments) { assessment in
                    GlassCard {
                        CreditTimingCardRow(assessment: assessment)
                    }
                }
            }
        }
    }
}

private struct CreditTimingCardRow: View {

    let assessment: CreditTimingCardAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            header

            if !assessment.outstandingChecks.isEmpty {
                CreditTimingInlineChecklist(items: assessment.outstandingChecks)
            } else {
                CreditTimingMetricsGrid(assessment: assessment)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            Image(systemName: assessment.ruling.systemImage)
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(assessment.accountName)
                    .font(TypographyTokens.body)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)

                if !assessment.institutionName.isEmpty {
                    Text(assessment.institutionName)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SpacingTokens.xSmall)

            StatusBadge(
                label: assessment.ruling.displayLabel,
                color: badgeColor(for: assessment.ruling),
                systemImage: assessment.ruling.systemImage
            )
            .accessibilityLabel(assessment.ruling.accessibilityLabel)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = [
            assessment.accountName,
            assessment.ruling.accessibilityLabel,
        ]
        if let band = assessment.utilizationBand {
            parts.append(band.accessibilityLabel)
        }
        if let close = assessment.statementClosingDate {
            let formatted = close.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("Statement closes \(formatted)")
        }
        if let due = assessment.paymentDueDate {
            let formatted = due.formatted(
                .dateTime.year().month(.wide).day()
            )
            parts.append("Payment due \(formatted)")
        }
        return parts.joined(separator: ", ")
    }

    private func badgeColor(
        for ruling: CreditTimingCardRuling
    ) -> Color {
        switch ruling {
        case .readyNoUrgentAction: ColorTokens.positive
        case .payDownBeforeClose: ColorTokens.warning
        case .nearLimitAvoidMoreSpend: ColorTokens.negative
        case .needsSetup, .snapshotStale, .scheduleMissing: ColorTokens.neutral
        }
    }
}

// MARK: - Inline checklist

private struct CreditTimingInlineChecklist: View {

    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
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

// MARK: - Metrics grid

private struct CreditTimingMetricsGrid: View {

    let assessment: CreditTimingCardAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            metricLine(
                label: "Utilization",
                value: utilizationText
            )
            if let balance = assessment.currentBalance {
                metricLine(
                    label: "Current balance",
                    value: balance.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let limit = assessment.creditLimit {
                metricLine(
                    label: "Credit limit",
                    value: limit.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let paydown = assessment.paydownTargetTo30Percent {
                metricLine(
                    label: "Paydown for 30% target",
                    value: paydown.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let paydown = assessment.paydownTargetTo10Percent {
                metricLine(
                    label: "Paydown for 10% target (optional)",
                    value: paydown.formatted(
                        .currency(code: assessment.currencyCode)
                    )
                )
            }
            if let close = assessment.statementClosingDate {
                metricLine(
                    label: "Statement closes",
                    value: close.formatted(
                        .dateTime.year().month(.wide).day()
                    )
                )
            }
            if let due = assessment.paymentDueDate {
                metricLine(
                    label: "Payment due",
                    value: due.formatted(
                        .dateTime.year().month(.wide).day()
                    )
                )
            }
            if let updatedAt = assessment.snapshotUpdatedAt {
                metricLine(
                    label: "Snapshot as of",
                    value: updatedAt.formatted(
                        .dateTime.year().month(.abbreviated).day()
                    )
                )
            }
        }
    }

    private var utilizationText: String {
        guard let util = assessment.utilization else {
            return "Unknown"
        }
        let percent = util * 100
        let formatted = percent.formatted(
            .number.precision(.fractionLength(1))
        )
        if let band = assessment.utilizationBand {
            return "\(formatted)% · \(band.displayLabel)"
        }
        return "\(formatted)%"
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

// MARK: - Checklist section

private struct CreditTimingChecklistSection: View {

    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Missing data")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    ForEach(items, id: \.self) { item in
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

// MARK: - Hard rules section

private struct CreditTimingHardRulesSection: View {

    let rules: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Hard rules")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            GlassCard {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    ForEach(rules, id: \.self) { rule in
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
}

// MARK: - Sources section

private struct CreditTimingSourcesSection: View {

    let citations: [ScenarioCitation]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Sources")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(citations) { citation in
                    Link(destination: citation.url) {
                        GlassCard {
                            CreditTimingSourceRow(citation: citation)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the official source in your browser.")
                }
            }
        }
    }
}

private struct CreditTimingSourceRow: View {

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

// MARK: - Evaluated-at note

private struct CreditTimingEvaluatedAtNote: View {

    let evaluatedAt: Date

    var body: some View {
        Text("Evaluated \(evaluatedAt.formatted(.dateTime.year().month(.wide).day().hour().minute()))")
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Evaluated as of \(evaluatedAt.formatted(.dateTime.year().month(.wide).day().hour().minute()))")
    }
}

#Preview {
    CreditTimingBriefView(accounts: [])
        .modelContainer(for: [Account.self], inMemory: true)
}
