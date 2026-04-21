// ScenarioDecisionBriefView.swift
// NomadFi
//
// Detail sheet for Scenario 1 — Amazon.com arrival order. Rendered as a
// read-only decision surface with local-only toggles that re-run the
// pure engine as the user confirms each check.

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
                    costBreakdownSection
                    paymentOptionsSection
                    chaseGuardrailSection
                    hardRulesSection
                    outstandingChecksSection
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

                Text("Toggle each item as you confirm it. Values are kept only for this session.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(
                    "Cart reviewed — paid / overnight shipping and accidental Subscribe & Save",
                    isOn: $viewModel.state.cartShippingReviewed
                )
                Toggle(
                    "Chase available credit confirmed (exceeds USD checkout + safety buffer)",
                    isOn: $viewModel.state.chaseAvailableCreditConfirmed
                )
                Toggle(
                    "Will pay Chase balance before next statement closes",
                    isOn: $viewModel.state.canPayBeforeStatementClose
                )
                Toggle(
                    "Wise USD balance is sufficient",
                    isOn: $viewModel.state.wiseBalanceSufficient
                )
                Toggle(
                    "Airbnb host can receive packages (or delivery timed for arrival)",
                    isOn: $viewModel.state.airbnbPackageReceiptConfirmed
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

                Text("Chase Freedom Rise is only recommended when available credit and statement-close timing are both confirmed. Without both, this tool routes to Wise USD or blocks on user input.")
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
}

#Preview {
    ScenarioDecisionBriefView(
        viewModel: ScenarioDecisionBriefViewModel()
    )
}
