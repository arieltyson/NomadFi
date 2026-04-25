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

    /// Transactions the Credit Timing brief uses to compute a
    /// deterministic spending-trend context. Sorted newest-first so
    /// the trend computer's window slicing reads naturally.
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    /// Jurisdictions for home-currency resolution. Mirrors the
    /// Dashboard query so the trend picks the same preferred
    /// currency the rest of the app renders net worth in.
    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

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

    /// Decision review markers (Credit Timing, future engines).
    /// Drives whether a catalog decision counts as "previously
    /// reviewed" — see `DecisionReviewEvidence`.
    @Query private var reviewMarkers: [DecisionReviewMarker]

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
                draftItems: DecisionDraftListPresentation
                    .decoratedActiveDrafts(
                        drafts,
                        accountSnapshot: draftAccountSnapshot
                    ),
                archivedDraftItems: DecisionDraftListPresentation
                    .decoratedArchivedDrafts(archivedDrafts),
                reviewedDecisions: viewModel.reviewedDecisions(
                    reviewMarkers: reviewMarkers
                ),
                onDraftTapped: { selectedDraft = $0 },
                onOpenDecision: { id in
                    viewModel.openDecision(id, modelContext: modelContext)
                }
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
            CreditTimingBriefView(
                accounts: accounts,
                spendingTrend: spendingTrendSummary
            )
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
        .sheet(isPresented: $viewModel.isAIIntakePresented) {
            DecisionAIIntakeSheet(
                interpreter: aiInterpreter,
                onSavedDraft: { draft in
                    Task { @MainActor in
                        selectedDraft = draft
                    }
                },
                onSwitchToTypedForm: {
                    Task { @MainActor in
                        viewModel.isAIIntakePresented = false
                        viewModel.presentDraftForm()
                    }
                }
            )
        }
        .sheet(item: $selectedDraft) { draft in
            DecisionDraftDetailView(
                draft: draft,
                onRequestEdit: handleRequestEdit,
                onRequestDelete: handleRequestDelete,
                onRequestHandoff: handleRequestHandoff,
                accountSnapshot: draftAccountSnapshot
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

    /// Phase 1 follow-through — routes a draft into the matching
    /// existing deterministic engine when the user explicitly taps
    /// a handoff button on the detail sheet. Dismisses the detail
    /// sheet first so SwiftUI never has two sheets in flight at
    /// once (Apple HIG).
    ///
    /// Honesty contract: this method never marks the draft itself
    /// as "analyzed". The draft's persisted
    /// ``DecisionDraftStatus`` stays unchanged.
    private func handleRequestHandoff(
        _ draft: DecisionDraftRecord,
        _ action: DecisionDraftNextAction
    ) {
        selectedDraft = nil
        Task { @MainActor in
            switch action {
            case .openPurchaseCheck:
                viewModel.openPurchaseDecisionBrief(prefillFrom: draft)
            case .openCreditTimingCheck:
                viewModel.openCreditTimingBrief()
            case .reviewInTaxVault, .reviewInInvestingLearn,
                 .addContext, .noEngineYet:
                break
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

    /// Home currency the Credit Timing brief prefers when picking
    /// the dominant currency for the spending trend. Mirrors the
    /// Dashboard's own home-currency resolution rule so both
    /// surfaces stay consistent.
    var homeCurrency: CurrencyCode {
        jurisdictions
            .first { $0.isHome }?
            .currencyCode ?? .usd
    }

    /// Deterministic spending-trend summary, or `nil` when the user
    /// doesn't have enough transactions for a meaningful trend.
    /// Computed lazily each time the sheet presents — the
    /// computer is pure and cheap on this scale.
    var spendingTrendSummary: SpendingTrendSummary? {
        SpendingTrendComputer.summary(
            transactions: transactions,
            homeCurrency: homeCurrency
        )
    }

    /// Phase 1 follow-through — minimal account projection the
    /// draft evaluator needs. Built fresh from the live `@Query`
    /// each time the detail sheet renders.
    var draftAccountSnapshot: DecisionDraftAccountSnapshot {
        DecisionDraftAccountSnapshot(
            hasAnyCreditCard: accounts.contains(where: \.isCreditCard)
        )
    }

    /// Phase 9A — production interpreter wired into the AI intake
    /// sheet. Resolves to the Foundation Models adapter on iOS 26+
    /// when available; the adapter itself is responsible for
    /// reporting `.foundationModelsUnavailable` cleanly when not.
    var aiInterpreter: DecisionDraftInterpreter {
        FoundationModelsDraftInterpreter()
    }
}

// MARK: - Content

/// Extracted so the root stays thin and each region composes as its
/// own `View` struct per the project style rules.
private struct DecisionAssistantContent: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]
    let creditCardAccounts: [Account]

    /// Active drafts already decorated with their evaluator-derived
    /// readiness and group-sorted by `DecisionDraftListPresentation`.
    /// Engine-ready drafts come first; archived drafts live in the
    /// quieter section below.
    let draftItems: [DecisionDraftListItem]

    /// Archived drafts decorated with the `.archived` readiness.
    /// Order preserved from the upstream `@Query` (`updatedAt`
    /// descending).
    let archivedDraftItems: [DecisionDraftListItem]

    let reviewedDecisions: [DecisionIdentity]
    let onDraftTapped: (DecisionDraftRecord) -> Void
    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        LazyVStack(spacing: SpacingTokens.large) {
            DecisionAssistantActiveSection(
                viewModel: viewModel,
                allAccounts: allAccounts
            )

            DecisionAssistantHistorySection(
                viewModel: viewModel,
                allAccounts: allAccounts,
                reviewedDecisions: reviewedDecisions,
                onOpenDecision: onOpenDecision
            )

            DecisionAssistantNewSection(viewModel: viewModel)

            DecisionAssistantDraftsSection(
                items: draftItems,
                onDraftTapped: onDraftTapped
            )

            if !archivedDraftItems.isEmpty {
                DecisionAssistantArchivedDraftsSection(
                    items: archivedDraftItems,
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

    /// Decisions the user has actually reviewed — filtered through
    /// `DecisionReviewEvidence`. Empty for fresh users, which is
    /// the path the empty-state copy is meant to hit.
    let reviewedDecisions: [DecisionIdentity]

    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Previous decisions",
                subtitle: "Decisions you've reviewed at least once on this device."
            )

            if reviewedDecisions.isEmpty {
                DecisionAssistantHistoryEmptyState()
            } else {
                DecisionAssistantHistoryList(
                    viewModel: viewModel,
                    allAccounts: allAccounts,
                    reviewedDecisions: reviewedDecisions,
                    onOpenDecision: onOpenDecision
                )
            }
        }
    }
}

private struct DecisionAssistantHistoryList: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]
    let reviewedDecisions: [DecisionIdentity]
    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(reviewedDecisions) { identity in
                let summary = viewModel.summary(
                    for: identity.id,
                    accounts: allAccounts
                )
                Button {
                    onOpenDecision(identity.id)
                } label: {
                    GlassCard {
                        DecisionHistoryRow(
                            identity: identity,
                            ruling: summary.ruling,
                            lastUpdatedAt: summary.lastUpdatedAt
                        )
                    }
                }
                .buttonStyle(.plain)
            }

            if reviewedDecisions.count == 1 {
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
            Text("More decisions will appear here as you review the others in the Now section.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "arrow.up.circle")
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
                onCaptureTapped: { viewModel.presentDraftForm() },
                onAppleIntelligenceTapped: { viewModel.presentAIIntake() }
            )
        }
    }
}

// MARK: - Drafts section

/// Shows captured drafts separately from the catalog-backed
/// "Previous decisions" list so the user can never mistake a raw
/// draft for an analyzed decision. Drafts v3 alignment: each row
/// surfaces evaluator-derived readiness ("Engine ready", "Add
/// amount first", "Review in Tax Vault", …) so the list is honest
/// at first glance about what NomadFi can do with each draft right
/// now. Engine-ready drafts surface first; the order otherwise
/// follows readiness group then `updatedAt` desc within each group.
private struct DecisionAssistantDraftsSection: View {

    let items: [DecisionDraftListItem]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Gathered intelligence",
                subtitle: "Saved drafts on this device. Each row shows what NomadFi can do with it right now."
            )

            if items.isEmpty {
                DecisionAssistantDraftsEmptyState()
            } else {
                DecisionAssistantDraftsList(
                    items: items,
                    onDraftTapped: onDraftTapped
                )
            }
        }
    }
}

private struct DecisionAssistantDraftsList: View {

    let items: [DecisionDraftListItem]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            ForEach(items) { item in
                Button {
                    onDraftTapped(item.draft)
                } label: {
                    GlassCard {
                        DecisionDraftRow(
                            draft: item.draft,
                            readiness: item.readiness
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the draft details. The detail sheet shows what NomadFi can do with this draft.")
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
                Text("Tap Capture decision above to save a scenario. NomadFi shows what it can do with each draft — open Purchase Card Check, open Credit Timing, or point at Tax Vault / Investing Learn — without auto-analyzing anything.")
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

    let items: [DecisionDraftListItem]
    let onDraftTapped: (DecisionDraftRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Archived drafts",
                subtitle: "Hidden from the main list. Tap to restore or delete permanently."
            )

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(items) { item in
                    Button {
                        onDraftTapped(item.draft)
                    } label: {
                        GlassCard {
                            DecisionDraftRow(
                                draft: item.draft,
                                readiness: item.readiness
                            )
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
        DecisionReviewMarker.self,
    ], inMemory: true)
}
