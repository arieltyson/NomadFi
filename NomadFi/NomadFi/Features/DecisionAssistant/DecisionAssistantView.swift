// DecisionAssistantView.swift
// NomadFi
//
// The Decisions tab's root screen. Composes three clearly-separated
// regions:
//
//   1. Active decision — a GlassCard hero that previews the current
//      ruling and opens the full `ScenarioDecisionBriefView` sheet.
//   2. Previous decisions — a section of saved decision records with
//      real "last updated" timestamps and a calm empty state.
//   3. Gather intelligence — a scaffold card naming the intake
//      channels that will land later (typed scenarios, Siri / App
//      Intents, Apple Intelligence context) without pretending any
//      of them work today.
//
// Uses `ScrollView { LazyVStack }` rather than `List` to match the
// Dashboard's visual language (GlassCard hero, section headers on a
// subtle gradient) — this is a command-center surface, not a settings
// list.

import SwiftData
import SwiftUI

/// The root of the Decisions tab. Uses `@Query` for reactive account
/// context (needed by the Scenario brief) and drives everything else
/// through ``DecisionAssistantViewModel``.
struct DecisionAssistantView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var accounts: [Account]

    @State private var viewModel = DecisionAssistantViewModel()

    var body: some View {
        ScrollView {
            DecisionAssistantContent(
                viewModel: viewModel,
                creditCardAccounts: creditCardAccounts
            )
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [ColorTokens.brandPrimary.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Decision Assistant")
        .glassToolbar()
        .task { viewModel.bootstrap(modelContext: modelContext) }
        .sheet(isPresented: $viewModel.isBriefPresented) {
            if let briefViewModel = viewModel.scenario1BriefViewModel {
                ScenarioDecisionBriefView(
                    viewModel: briefViewModel,
                    creditCardAccounts: creditCardAccounts
                )
            }
        }
    }
}

// MARK: - Helpers

private extension DecisionAssistantView {

    /// Credit-card accounts sorted to match the Settings order so the
    /// brief's linked-card picker stays consistent with Credit Card
    /// Calendar. Mirrors the helper that used to live on Dashboard.
    var creditCardAccounts: [Account] {
        accounts
            .filter { $0.accountType == .creditCard }
            .sorted { lhs, rhs in
                if lhs.institutionName == rhs.institutionName {
                    return lhs.name < rhs.name
                }
                return lhs.institutionName < rhs.institutionName
            }
    }
}

// MARK: - Content

/// Extracted so the root stays thin and each region composes as its
/// own `View` struct per the project style rules.
private struct DecisionAssistantContent: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let creditCardAccounts: [Account]

    var body: some View {
        LazyVStack(spacing: SpacingTokens.large) {
            DecisionAssistantActiveSection(viewModel: viewModel)

            DecisionAssistantHistorySection(viewModel: viewModel)

            DecisionAssistantNewSection()

            DecisionAssistantFooterNote()
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.medium)
    }
}

// MARK: - Active section

private struct DecisionAssistantActiveSection: View {

    @Bindable var viewModel: DecisionAssistantViewModel

    var body: some View {
        if let active = viewModel.activeDecision {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                DecisionAssistantSectionHeader(
                    title: "Now",
                    subtitle: "Where NomadFi has a deterministic recommendation."
                )

                ActiveDecisionHeroCard(
                    identity: active,
                    ruling: viewModel.activeDecisionRuling,
                    lastUpdatedAt: viewModel.activeDecisionLastUpdatedAt,
                    outstandingCheckCount: viewModel.activeDecisionOutstandingCheckCount,
                    action: { viewModel.openActiveDecision() }
                )
            }
        }
    }
}

// MARK: - History section

private struct DecisionAssistantHistorySection: View {

    @Bindable var viewModel: DecisionAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Previous decisions",
                subtitle: "Saved inputs for decisions you've reviewed before."
            )

            if viewModel.historicalDecisions.isEmpty {
                DecisionAssistantHistoryEmptyState()
            } else {
                DecisionAssistantHistoryList(viewModel: viewModel)
            }
        }
    }
}

private struct DecisionAssistantHistoryList: View {

    @Bindable var viewModel: DecisionAssistantViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(viewModel.historicalDecisions) { identity in
                Button {
                    viewModel.openDecision(identity.id)
                } label: {
                    GlassCard {
                        DecisionHistoryRow(
                            identity: identity,
                            ruling: viewModel.activeDecisionRuling,
                            lastUpdatedAt: viewModel.activeDecisionLastUpdatedAt,
                            isInteracted: viewModel.hasInteractedWithActiveDecision
                        )
                    }
                }
                .buttonStyle(.plain)
            }

            if viewModel.historicalDecisions.count == 1 {
                DecisionAssistantHistoryHorizon()
            }
        }
    }
}

private struct DecisionAssistantHistoryEmptyState: View {

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("No previous decisions yet")
                    .font(TypographyTokens.body)
                Text("Open a decision from the Now section to start a record NomadFi can reopen later.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct DecisionAssistantHistoryHorizon: View {

    var body: some View {
        Label {
            Text("More decisions will appear here as NomadFi ships deterministic engines for them.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "hourglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.xxSmall)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - New decision section

private struct DecisionAssistantNewSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Gather intelligence",
                subtitle: "Future intake channels for new decisions."
            )

            NewDecisionScaffoldCard()
        }
    }
}

// MARK: - Footer note

private struct DecisionAssistantFooterNote: View {

    var body: some View {
        Text("Decision support only. NomadFi distinguishes screenshot facts, official-source checks, user inputs, and inference — and never labels AI-assisted drafts as verified.")
            .font(TypographyTokens.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Decision support only. NomadFi distinguishes screenshot facts, official-source checks, user inputs, and inference, and never labels AI-assisted drafts as verified.")
    }
}

// MARK: - Section header

private struct DecisionAssistantSectionHeader: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(title)
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        DecisionAssistantView()
    }
    .modelContainer(for: [
        Currency.self,
        JurisdictionProfile.self,
        Account.self,
        Transaction.self,
        ExchangeRate.self,
        TaxDocument.self,
        Subscription.self,
        Budget.self,
        ScenarioDecisionRecord.self,
    ], inMemory: true)
}
