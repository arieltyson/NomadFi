// CreditLimitReadinessChecklist.swift
// NomadFi
//
// Top-level readiness output. The product rule is explicit: NomadFi
// never tells the user to *request* a credit-limit increase and
// never claims an issuer will approve one. The surface is a
// "ready to review with your issuer" / "needs more evidence"
// checklist, not a recommendation.

import Foundation

/// Whether a card's readiness summary is closer to "ready to review"
/// or "needs more evidence". Never "approved" or "you should
/// request".
enum CreditLimitReadinessSummary: String, Sendable, Equatable, CaseIterable {

    /// Every NomadFi-visible check passes and the issuer-only facts
    /// are surfaced for the user to confirm with their issuer.
    case readyToReview

    /// One or more NomadFi-visible checks still need user action.
    case needsMoreEvidence

    // MARK: - Display

    var displayLabel: String {
        switch self {
        case .readyToReview: "Ready to review"
        case .needsMoreEvidence: "Needs more evidence"
        }
    }

    /// VoiceOver phrasing.
    var accessibilityLabel: String {
        switch self {
        case .readyToReview:
            "Ready to review with your card issuer. NomadFi does not predict approval."
        case .needsMoreEvidence:
            "Needs more evidence from your side before NomadFi can summarise readiness."
        }
    }
}

/// Per-card readiness summary plus the underlying checks.
struct CreditLimitReadinessCardSummary: Sendable, Equatable, Identifiable {
    let id: String
    let accountName: String
    let institutionName: String
    let currencyCode: String

    /// Final per-card status rolled up from ``items``.
    let summary: CreditLimitReadinessSummary

    /// Ordered checks. The UI renders them in this exact order.
    let items: [CreditLimitReadinessItem]
}

/// Portfolio-wide readiness checklist. The view renders each card's
/// section under a short "NomadFi does not request limits on your
/// behalf" header so the surface stays calm and honest.
struct CreditLimitReadinessChecklist: Sendable, Equatable {

    /// Per-card summaries, sorted by severity (needsMoreEvidence
    /// first so the user sees the actionable cards at the top).
    let cardSummaries: [CreditLimitReadinessCardSummary]

    /// Global caveats pinned at the top of the UI. Never empty — the
    /// issuer-only caveat always appears.
    let globalCaveats: [String]

    /// Evaluation moment the engine injected.
    let evaluatedAt: Date

    // MARK: - Derived

    /// Count of cards where every NomadFi-visible check passes.
    var readyToReviewCount: Int {
        cardSummaries.lazy
            .filter { $0.summary == .readyToReview }
            .count
    }

    /// Count of cards that still need user-side evidence.
    var needsMoreEvidenceCount: Int {
        cardSummaries.lazy
            .filter { $0.summary == .needsMoreEvidence }
            .count
    }
}
