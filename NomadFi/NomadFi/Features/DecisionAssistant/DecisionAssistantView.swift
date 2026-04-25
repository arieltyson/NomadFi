// DecisionAssistantView.swift
// NomadFi
//
// The Decisions tab's root screen. IA/UI redesign: the surface is
// organised into six sectioned bands so the user immediately sees
// (1) how to start a decision, (2) which checks are reusable
// tools, (3) which scenarios are pinned, (4) which decisions they
// have actually reviewed, (5) where captured drafts live, and
// (6) which drafts they have archived. Lower-priority sections
// progressively disclose so the screen never feels infinite.
//
// Layout follows Apple's HIG layout + scroll-views + accessibility
// guidance:
//   • One primary vertical scroll only.
//   • Strong section headers per region; calm visual hierarchy.
//   • Capture decision is the dominant first-viewport command.
//   • Reusable tools, pinned scenarios, history, and drafts each
//     read as a different kind of thing.
//   • Drafts and archived drafts cap at a small preview with a
//     calm "Show all" disclosure when there is more to see.
//
// The screen never fakes data — empty states stay reachable for
// fresh users (no previous decisions, no captured drafts).

import SwiftData
import SwiftUI

/// The root of the Decisions tab. Uses `@Query` for reactive
/// account context (needed by the Scenario brief) and drives
/// everything else through ``DecisionAssistantViewModel``.
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
    /// excluded — they render in their own quieter section below.
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

    /// One-shot scenario seed handed across by `OpenAIIntakeIntent`
    /// (Siri / Shortcuts), `StartAIIntakeIntent` (Control Widget /
    /// Lock Screen / Action button), or any future routing entry
    /// via `PendingAIIntakeRequestStore`. Read reactively through
    /// `@AppStorage(_:store:)` against the App Group shared suite
    /// (``AppRoutingDefaults/shared``) so writes from the widget
    /// extension's process — not just the main app's — observe
    /// here, regardless of which process iOS dispatched the
    /// intent in.
    @AppStorage(PendingAIIntakeRequest.storageKey, store: AppRoutingDefaults.shared)
    private var pendingAIIntakeRaw: String = ""

    /// Per-presentation seed text passed into `DecisionAIIntakeSheet`.
    /// Cleared after the sheet dismisses so a re-open without an
    /// intent never re-seeds previously-typed text.
    @State private var aiIntakeSeedText: String = ""

    /// Currently-selected draft for the detail sheet.
    @State private var selectedDraft: DecisionDraftRecord?

    /// Draft being edited. Mutually exclusive with `selectedDraft`
    /// by construction so SwiftUI never has two sheets open at
    /// once (Apple HIG).
    @State private var draftBeingEdited: DecisionDraftRecord?

    /// Whether the drafts section is showing every captured draft
    /// or only the top preview window. Local UI state — never
    /// persisted, never needs CloudKit.
    @State private var draftsExpanded = false

    /// Same disclosure flag for the archived-drafts section.
    @State private var archivedDraftsExpanded = false

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
                draftsExpanded: $draftsExpanded,
                archivedDraftsExpanded: $archivedDraftsExpanded,
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
        .navigationTitle("Decisions")
        .glassToolbar()
        .task { viewModel.bootstrap(modelContext: modelContext) }
        .onChange(of: pendingAIIntakeRaw, initial: true) { _, _ in
            consumePendingAIIntakeIfAvailable()
        }
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
        .sheet(
            isPresented: $viewModel.isAIIntakePresented,
            onDismiss: { aiIntakeSeedText = "" }
        ) {
            DecisionAIIntakeSheet(
                interpreter: aiInterpreter,
                seedScenarioText: aiIntakeSeedText,
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

    /// Consumes a pending AI-intake request from the system-surface
    /// hand-off slot (`PendingAIIntakeRequestStore`) when one is
    /// available, seeds the AI intake sheet's scenario field, and
    /// presents the sheet. One-shot — `consume` clears the slot
    /// atomically so the sheet does not keep reappearing if the
    /// view re-renders, and `aiIntakeSeedText` is cleared on sheet
    /// dismissal so a re-open without a fresh intent never silently
    /// re-seeds previously-typed text.
    ///
    /// Two launch shapes feed the same consumer:
    ///   • Siri / Shortcut (`OpenAIIntakeIntent`) supplies a
    ///     dictated scenario — `request.scenarioText` is non-nil.
    ///   • Control Widget / Lock Screen / Action button
    ///     (`StartAIIntakeIntent`) supplies a blank-launch payload
    ///     — `request.scenarioText` is nil; the sheet opens with
    ///     an empty scenario field ready for typing.
    ///
    /// Honesty contract: the request only carries an optional
    /// scenario string. Interpretation, the bounded clarifying
    /// loop, and persistence all happen in-app with explicit user
    /// confirmation — same as the in-app AI intake entry point.
    private func consumePendingAIIntakeIfAvailable() {
        guard let request = PendingAIIntakeRequestStore.consume() else {
            return
        }
        aiIntakeSeedText = request.scenarioText ?? ""
        viewModel.presentAIIntake()
    }

    /// Closes the detail sheet and, on the next runloop turn, opens
    /// the edit form for the same draft.
    private func handleRequestEdit(_ draft: DecisionDraftRecord) {
        selectedDraft = nil
        Task { @MainActor in
            draftBeingEdited = draft
        }
    }

    /// Deletes a draft after the confirmation dialog has already
    /// been accepted by the user.
    private func handleRequestDelete(_ draft: DecisionDraftRecord) {
        selectedDraft = nil
        Task { @MainActor in
            DecisionDraftStore.delete(draft, in: modelContext)
        }
    }

    /// Routes a draft into the matching existing deterministic
    /// engine when the user explicitly taps a handoff button on
    /// the detail sheet. Drafts v2 / v3 contract: this never marks
    /// the draft itself as "analyzed".
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

    /// Credit-card accounts sorted to match the Settings order so
    /// the brief's linked-card picker stays consistent with the
    /// Credit Card Calendar.
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
    /// the dominant currency for the spending trend.
    var homeCurrency: CurrencyCode {
        jurisdictions
            .first { $0.isHome }?
            .currencyCode ?? .usd
    }

    /// Deterministic spending-trend summary, or `nil` when the
    /// user doesn't have enough transactions for a meaningful
    /// trend.
    var spendingTrendSummary: SpendingTrendSummary? {
        SpendingTrendComputer.summary(
            transactions: transactions,
            homeCurrency: homeCurrency
        )
    }

    /// Phase 1 follow-through — minimal account projection the
    /// draft evaluator needs.
    var draftAccountSnapshot: DecisionDraftAccountSnapshot {
        DecisionDraftAccountSnapshot(
            hasAnyCreditCard: accounts.contains(where: \.isCreditCard)
        )
    }

    /// Phase 9A — production interpreter wired into the AI intake
    /// sheet. Resolves to the Foundation Models adapter on iOS 26+.
    var aiInterpreter: DecisionDraftInterpreter {
        FoundationModelsDraftInterpreter()
    }
}

// MARK: - Content

/// Composes the six redesigned sections in IA order. Extracted so
/// the root stays thin and each section composes as its own view.
private struct DecisionAssistantContent: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]
    let creditCardAccounts: [Account]

    /// Active drafts already decorated with their evaluator-derived
    /// readiness and group-sorted by `DecisionDraftListPresentation`.
    let draftItems: [DecisionDraftListItem]

    /// Archived drafts decorated with the `.archived` readiness.
    let archivedDraftItems: [DecisionDraftListItem]

    let reviewedDecisions: [DecisionIdentity]

    @Binding var draftsExpanded: Bool
    @Binding var archivedDraftsExpanded: Bool

    let onDraftTapped: (DecisionDraftRecord) -> Void
    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        LazyVStack(spacing: SpacingTokens.large) {

            // 1. Capture decision — primary command module.
            DecisionAssistantCaptureSection(viewModel: viewModel)

            // 2. Reusable checks — evergreen tools.
            DecisionAssistantReusableChecksSection(
                viewModel: viewModel,
                onOpenDecision: onOpenDecision
            )

            // 3. Pinned scenario — situational, not a tool.
            DecisionAssistantPinnedScenarioSection(
                viewModel: viewModel,
                allAccounts: allAccounts,
                onOpenDecision: onOpenDecision
            )

            // 4. Previous decisions — actually reviewed only.
            DecisionAssistantHistorySection(
                viewModel: viewModel,
                allAccounts: allAccounts,
                reviewedDecisions: reviewedDecisions,
                onOpenDecision: onOpenDecision
            )

            // 5. Captured drafts — saved raw context.
            DecisionAssistantDraftsSection(
                items: draftItems,
                expanded: $draftsExpanded,
                onDraftTapped: onDraftTapped
            )

            // 6. Archived drafts — only when non-empty.
            if !archivedDraftItems.isEmpty {
                DecisionAssistantArchivedDraftsSection(
                    items: archivedDraftItems,
                    expanded: $archivedDraftsExpanded,
                    onDraftTapped: onDraftTapped
                )
            }

            DecisionAssistantFooterNote()
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.medium)
    }
}

// MARK: - 1. Capture decision

private struct DecisionAssistantCaptureSection: View {

    @Bindable var viewModel: DecisionAssistantViewModel

    var body: some View {
        DecisionAssistantCaptureHero(
            onCaptureTapped: { viewModel.presentDraftForm() },
            onAppleIntelligenceTapped: { viewModel.presentAIIntake() }
        )
    }
}

// MARK: - 2. Reusable checks

private struct DecisionAssistantReusableChecksSection: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        if !viewModel.reusableChecks.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                DecisionAssistantSectionHeader(
                    title: "Reusable checks",
                    subtitle: "Evergreen tools you can run any time."
                )

                VStack(spacing: SpacingTokens.xSmall) {
                    ForEach(viewModel.reusableChecks) { identity in
                        ReusableCheckCard(
                            identity: identity,
                            action: { onOpenDecision(identity.id) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 3. Pinned scenario

private struct DecisionAssistantPinnedScenarioSection: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]
    let onOpenDecision: (DecisionID) -> Void

    var body: some View {
        if !viewModel.pinnedScenarios.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                DecisionAssistantSectionHeader(
                    title: "Pinned scenario",
                    subtitle: "A specific decision NomadFi keeps visible because it's ongoing."
                )

                VStack(spacing: SpacingTokens.xSmall) {
                    ForEach(viewModel.pinnedScenarios) { identity in
                        let summary = viewModel.summary(
                            for: identity.id,
                            accounts: allAccounts
                        )
                        ScenarioPinnedCard(
                            identity: identity,
                            ruling: summary.ruling,
                            lastUpdatedAt: summary.lastUpdatedAt,
                            outstandingCheckCount: summary.outstandingCheckCount,
                            action: { onOpenDecision(identity.id) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 4. Previous decisions

private struct DecisionAssistantHistorySection: View {

    @Bindable var viewModel: DecisionAssistantViewModel
    let allAccounts: [Account]

    /// Decisions the user has actually reviewed — filtered through
    /// `DecisionReviewEvidence`. Empty for fresh users; the
    /// empty-state path stays reachable.
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
        }
    }
}

private struct DecisionAssistantHistoryEmptyState: View {

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("No previous decisions yet")
                    .font(TypographyTokens.body)
                Text("Open a reusable check or the pinned scenario above to start a record NomadFi can reopen later.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 5. Captured drafts

/// Drafts v3 alignment preserved: each row surfaces evaluator-
/// derived readiness ("Engine ready", "Add amount first", "Review
/// in Tax Vault", …). The IA redesign caps the visible window at a
/// small preview and exposes a calm "Show all" disclosure when
/// there is more to see — Apple's progressive-disclosure pattern.
private struct DecisionAssistantDraftsSection: View {

    let items: [DecisionDraftListItem]

    @Binding var expanded: Bool

    let onDraftTapped: (DecisionDraftRecord) -> Void

    /// Default preview window for the active draft list. Three
    /// rows is enough to communicate the section without dragging
    /// the screen below the fold.
    private static let previewLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Captured drafts",
                subtitle: "Saved raw context. Each row shows what NomadFi can do with it right now."
            )

            if items.isEmpty {
                DecisionAssistantDraftsEmptyState()
            } else {
                DecisionAssistantDraftsList(
                    items: visibleItems,
                    onDraftTapped: onDraftTapped
                )

                if items.count > Self.previewLimit {
                    DecisionAssistantShowMoreRow(
                        expanded: $expanded,
                        totalCount: items.count,
                        previewLimit: Self.previewLimit,
                        noun: "draft"
                    )
                }
            }
        }
    }

    private var visibleItems: [DecisionDraftListItem] {
        if expanded || items.count <= Self.previewLimit {
            return items
        }
        return Array(items.prefix(Self.previewLimit))
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
                Text("Tap Capture decision above to save a scenario. NomadFi shows what it can do with each draft on its detail sheet — without auto-analyzing anything.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 6. Archived drafts

/// Quieter secondary list of archived drafts. Only renders when
/// the user actually has archived drafts. Same progressive-
/// disclosure pattern as the captured-drafts section so the
/// archive doesn't bloat the surface.
private struct DecisionAssistantArchivedDraftsSection: View {

    let items: [DecisionDraftListItem]

    @Binding var expanded: Bool

    let onDraftTapped: (DecisionDraftRecord) -> Void

    private static let previewLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            DecisionAssistantSectionHeader(
                title: "Archived drafts",
                subtitle: "Hidden from the main list. Tap to restore or delete permanently."
            )

            VStack(spacing: SpacingTokens.xSmall) {
                ForEach(visibleItems) { item in
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

            if items.count > Self.previewLimit {
                DecisionAssistantShowMoreRow(
                    expanded: $expanded,
                    totalCount: items.count,
                    previewLimit: Self.previewLimit,
                    noun: "archived draft"
                )
            }
        }
    }

    private var visibleItems: [DecisionDraftListItem] {
        if expanded || items.count <= Self.previewLimit {
            return items
        }
        return Array(items.prefix(Self.previewLimit))
    }
}

// MARK: - Show-more disclosure

/// Calm progressive-disclosure row used by the drafts and
/// archived-drafts sections. Tapping toggles the section between
/// preview and fully expanded. No magic numbers — both call sites
/// pass their own `previewLimit`.
private struct DecisionAssistantShowMoreRow: View {

    @Binding var expanded: Bool
    let totalCount: Int
    let previewLimit: Int
    let noun: String

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: SpacingTokens.xSmall) {
                Image(systemName: expanded ? "chevron.up.circle" : "chevron.down.circle")
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
                Text(label)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.brandPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, SpacingTokens.xxSmall)
            .padding(.horizontal, SpacingTokens.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        if expanded {
            return "Show fewer"
        }
        let hidden = totalCount - previewLimit
        let suffix = hidden == 1 ? noun : "\(noun)s"
        return "Show all (\(hidden) more \(suffix))"
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
