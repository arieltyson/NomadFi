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

    /// Active decision drafts, newest first. Archived drafts are
    /// excluded — they render in their own section below.
    @Query(
        filter: #Predicate<DecisionDraftRecord> {
            $0.statusRawValue == "needsEngine"
        },
        sort: \DecisionDraftRecord.updatedAt,
        order: .reverse
    )
    private var drafts: [DecisionDraftRecord]

    /// Archived drafts, newest first. Rendered in a quieter,
    /// secondary section that only appears when non-empty so the
    /// main Decision Assistant surface stays focused.
    @Query(
        filter: #Predicate<DecisionDraftRecord> {
            $0.statusRawValue == "archived"
        },
        sort: \DecisionDraftRecord.updatedAt,
        order: .reverse
    )
    private var archivedDrafts: [DecisionDraftRecord]

    @State private var viewModel = DecisionAssistantViewModel()

    /// Currently-selected draft for the detail sheet. Kept as
    /// view-local state because the sheet presentation binds to an
    /// `Identifiable` record, which stays cleaner here than on the
    /// view model.
    @State private var selectedDraft: DecisionDraftRecord?

    /// Draft being edited. Mutually exclusive with `selectedDraft`
    /// by construction: Edit requests from the detail sheet first
    /// clear `selectedDraft` and then set `draftBeingEdited`, so we
    /// never have two sheets open at once (Apple HIG).
    @State private var draftBeingEdited: DecisionDraftRecord?

    var body: some View {
        ScrollView {
            DecisionAssistantContent(
                viewModel: viewModel,
                allAccounts: accounts,
                creditCardAccounts: creditCardAccounts,
                drafts: drafts,
                archivedDrafts: archivedDrafts,
                onDraftTapped: { selectedDraft = $0 }
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
        .sheet(isPresented: $viewModel.isCreditTimingBriefPresented) {
            CreditTimingBriefView(accounts: accounts)
        }
        .sheet(isPresented: $viewModel.isPurchaseDecisionBriefPresented) {
            if let purchaseBriefViewModel = viewModel.purchaseDecisionBriefViewModel {
                PurchaseDecisionBriefView(
                    accounts: accounts,
                    viewModel: purchaseBriefViewModel
                )
            }
        }
        .sheet(isPresented: $viewModel.isDraftFormPresented) {
            DecisionDraftFormView()
        }
        .sheet(item: $selectedDraft) { draft in
            DecisionDraftDetailView(
                draft: draft,
                onRequestEdit: handleRequestEdit,
                onRequestDelete: handleRequestDelete
            )
        }
        .sheet(item: $draftBeingEdited) { draft in
            DecisionDraftFormView(draft: draft)
        }
    }

    // MARK: - Lifecycle handlers

    /// Closes the detail sheet and, on the next runloop turn, opens
    /// the edit form for the same draft. The tiny `Task` defer keeps
    /// SwiftUI from fighting a "dismiss one sheet + present another"
    /// in the same frame, which can leave the edit sheet stranded.
    private func handleRequestEdit(_ draft: DecisionDraftRecord) {
        selectedDraft = nil
        Task { @MainActor in
            draftBeingEdited = draft
        }
    }

    /// Deletes a draft after the confirmation dialog has already
    /// been accepted by the user. Dismisses the detail sheet first
    /// so SwiftData's delete doesn't race a sheet that's still
    /// reading the record.
    private func handleRequestDelete(_ draft: DecisionDraftRecord) {
        selectedDraft = nil
        Task { @MainActor in
            DecisionDraftStore.delete(draft, in: modelContext)
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
    let allAccounts: [Account]
    let creditCardAccounts: [Account]
    let drafts: [DecisionDraftRecord]
    let archivedDrafts: [DecisionDraftRecord]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        LazyVStack(spacing: SpacingTokens.large) {
            DecisionAssistantActiveSection(
                viewModel: viewModel,
                allAccounts: allAccounts
            )

            DecisionAssistantHistorySection(
                viewModel: viewModel,
                allAccounts: allAccounts
            )

            DecisionAssistantNewSection(viewModel: viewModel)

            DecisionAssistantDraftsSection(
                drafts: drafts,
                onDraftTapped: onDraftTapped
            )

            if !archivedDrafts.isEmpty {
                DecisionAssistantArchivedDraftsSection(
                    drafts: archivedDrafts,
                    onDraftTapped: onDraftTapped
                )
            }

            DecisionAssistantFooterNote()
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.medium)
    }
}

// MARK: - Active section

private struct DecisionAssistantActiveSection: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]

    var body: some View {
        if !viewModel.activeDecisions.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                DecisionAssistantSectionHeader(
                    title: "Now",
                    subtitle: "Where NomadFi has a deterministic recommendation."
                )

                VStack(spacing: SpacingTokens.small) {
                    ForEach(viewModel.activeDecisions) { identity in
                        let summary = viewModel.summary(
                            for: identity.id,
                            accounts: allAccounts
                        )
                        ActiveDecisionHeroCard(
                            identity: identity,
                            ruling: summary.ruling,
                            lastUpdatedAt: summary.lastUpdatedAt,
                            outstandingCheckCount: summary.outstandingCheckCount,
                            action: { viewModel.openDecision(identity.id) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - History section

private struct DecisionAssistantHistorySection: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Previous decisions",
                subtitle: "Saved inputs for decisions you've reviewed before."
            )

            if viewModel.historicalDecisions.isEmpty {
                DecisionAssistantHistoryEmptyState()
            } else {
                DecisionAssistantHistoryList(
                    viewModel: viewModel,
                    allAccounts: allAccounts
                )
            }
        }
    }
}

private struct DecisionAssistantHistoryList: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(viewModel.historicalDecisions) { identity in
                let summary = viewModel.summary(
                    for: identity.id,
                    accounts: allAccounts
                )
                Button {
                    viewModel.openDecision(identity.id)
                } label: {
                    GlassCard {
                        DecisionHistoryRow(
                            identity: identity,
                            ruling: summary.ruling,
                            lastUpdatedAt: summary.lastUpdatedAt,
                            isInteracted: isInteracted(with: identity)
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

    /// Per-decision interaction flag. Scenario 1 uses the VM's
    /// existing helper; Credit Timing treats "interacted" as "at
    /// least one credit card exists on file" since the engine doesn't
    /// require additional user input beyond the saved cards.
    private func isInteracted(with identity: DecisionIdentity) -> Bool {
        switch identity.id {
        case .amazonArrivalOrder:
            return viewModel.hasInteractedWithActiveDecision
        case .creditTimingCheck:
            return allAccounts.contains(where: \.isCreditCard)
        case .purchaseCardCheck:
            return viewModel.purchaseDecisionBriefViewModel?.record.hasUsableContext ?? false
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

    @Bindable var viewModel: DecisionAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Gather intelligence",
                subtitle: "Capture a scenario locally — NomadFi stores it until a deterministic engine can analyze it."
            )

            NewDecisionScaffoldCard(
                onCaptureTapped: { viewModel.presentDraftForm() }
            )
        }
    }
}

// MARK: - Drafts section

/// Shows captured drafts separately from the catalog-backed "Previous
/// decisions" list so the user can never mistake a raw draft for an
/// analyzed decision. Renders an empty-state pointer when no drafts
/// exist yet, or a glass-card list sorted by `updatedAt` descending.
private struct DecisionAssistantDraftsSection: View {

    let drafts: [DecisionDraftRecord]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Gathered intelligence",
                subtitle: "Saved drafts on this device. Not yet analyzed."
            )

            if drafts.isEmpty {
                DecisionAssistantDraftsEmptyState()
            } else {
                DecisionAssistantDraftsList(
                    drafts: drafts,
                    onDraftTapped: onDraftTapped
                )
            }
        }
    }
}

private struct DecisionAssistantDraftsList: View {

    let drafts: [DecisionDraftRecord]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(drafts) { draft in
                Button {
                    onDraftTapped(draft)
                } label: {
                    GlassCard {
                        DecisionDraftRow(draft: draft)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the captured draft details. Read-only.")
            }
        }
    }
}

private struct DecisionAssistantDraftsEmptyState: View {

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("No drafts captured yet")
                    .font(TypographyTokens.body)
                Text("Tap Capture decision above to save a scenario. Drafts stay on this device and are marked Needs engine until a deterministic NomadFi engine covers them.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Archived drafts section

/// Quieter secondary list of archived drafts. Only renders when the
/// user actually has archived drafts, so the Decision Assistant's
/// primary surface stays focused on actionable captures. Archived
/// rows are dimmed to make the status visually unambiguous without
/// relying on colour alone.
private struct DecisionAssistantArchivedDraftsSection: View {

    let drafts: [DecisionDraftRecord]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Archived drafts",
                subtitle: "Hidden from the main list. Tap to restore or delete permanently."
            )

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(drafts) { draft in
                    Button {
                        onDraftTapped(draft)
                    } label: {
                        GlassCard {
                            DecisionDraftRow(draft: draft)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(0.72)
                    .accessibilityHint("Opens the archived draft. Restore or delete from the detail sheet.")
                }
            }
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
        DecisionDraftRecord.self,
        PurchaseDecisionRecord.self,
    ], inMemory: true)
}
