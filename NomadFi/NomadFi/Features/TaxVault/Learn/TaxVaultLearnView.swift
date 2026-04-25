// TaxVaultLearnView.swift
// NomadFi
//
// Learn is the "understand it" surface — source-backed education
// starter, per-region progression, knowledge-check quizzes, a calm
// recognition strip, and (Phase 7E) a deterministic organization-
// prompt section that bridges Learn to Review or Archive when the
// user is ready to act on what they just read. No scan CTA here
// (that belongs to Review), no archive noise (that belongs to
// Archive).

import SwiftData
import SwiftUI

struct TaxVaultLearnView: View {

    let progressRecords: [TaxEducationProgressRecord]
    let modelContext: ModelContext

    @Bindable var education: TaxEducationViewModel

    /// Active jurisdictions — feeds both the existing education
    /// section and the Phase 7E organization-prompt section.
    let jurisdictions: [JurisdictionProfile]

    /// Documents already on file — only used to decide whether the
    /// per-region action prompt routes to Review or Archive.
    let documents: [TaxDocument]

    /// Called when the user taps a prompt's primary action button.
    /// Parent (`TaxVaultView`) flips its `@State` `surface` so
    /// Learn can hand off to a peer surface without a new
    /// navigation destination.
    let onRequestSurface: (TaxVaultSurface) -> Void

    /// Derived per refresh — recomputed as the VM bundles change.
    var recognition: TaxEducationRecognitionSummary {
        TaxEducationRecognitionComputer.summary(
            for: education.regionBundles,
            in: progressRecords
        )
    }

    /// Deterministic prompt list for the current archive state.
    var organizationPrompts: [TaxDocumentOrganizationPrompt] {
        TaxDocumentOrganizationPromptService.prompts(
            for: jurisdictions,
            documents: documents
        )
    }

    var body: some View {
        if education.hasContent {
            List {
                if !recognition.portfolioBadges.isEmpty {
                    recognitionSection
                }
                TaxDocumentOrganizationPromptSection(
                    prompts: organizationPrompts,
                    onSelectTarget: handleOrganizationTarget(_:)
                )
                TaxEducationSection(
                    bundles: education.regionBundles,
                    progressRecords: progressRecords,
                    summary: { bundle in
                        education.summary(for: bundle, in: progressRecords)
                    },
                    nextStep: { bundle in
                        education.nextStep(for: bundle, in: progressRecords)
                    },
                    isLessonReviewed: { lesson in
                        education.isLessonReviewed(lesson, in: progressRecords)
                    },
                    isChecklistItemCompleted: { item, region in
                        education.isChecklistItemCompleted(
                            item,
                            region: region,
                            in: progressRecords
                        )
                    },
                    isQuizUnlocked: { bundle in
                        education.isQuizUnlocked(for: bundle, in: progressRecords)
                    },
                    regionBadges: { region in
                        recognition.badgesByRegion[region] ?? []
                    },
                    onSelectLesson: { education.select($0) },
                    onToggleChecklistItem: { item, region in
                        education.toggleChecklistItem(
                            item,
                            region: region,
                            in: modelContext,
                            records: progressRecords
                        )
                    },
                    onOpenQuiz: { education.selectQuiz($0) }
                )
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
        } else {
            emptyState
        }
    }

    // MARK: - Sections

    private var recognitionSection: some View {
        Section {
            TaxEducationRecognitionStrip(summary: recognition)
                .listRowInsets(EdgeInsets(
                    top: SpacingTokens.xSmall,
                    leading: SpacingTokens.medium,
                    bottom: SpacingTokens.xSmall,
                    trailing: SpacingTokens.medium
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No jurisdictions on file", systemImage: "books.vertical")
        } description: {
            Text("Add a jurisdiction in Settings → Jurisdictions. NomadFi ships short, source-backed lessons for supported regions.")
        }
    }

    // MARK: - Routing

    /// Translates a prompt-card action target into a Tax Vault
    /// peer-surface request. `.none` is a no-op so source-only
    /// cards never trigger a surface switch.
    private func handleOrganizationTarget(
        _ target: TaxDocumentOrganizationPromptTarget
    ) {
        switch target {
        case .review:
            onRequestSurface(.review)
        case .archive:
            onRequestSurface(.archive)
        case .none:
            break
        }
    }
}
