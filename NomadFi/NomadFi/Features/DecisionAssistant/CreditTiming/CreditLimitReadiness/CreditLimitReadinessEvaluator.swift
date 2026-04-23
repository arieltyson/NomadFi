// CreditLimitReadinessEvaluator.swift
// NomadFi
//
// Pure evaluator. Takes the engine's per-card assessments and
// produces a ``CreditLimitReadinessChecklist``. Follows three
// non-negotiable product rules:
//
//   1. NomadFi never says "request a credit-limit increase" or
//      "you'll be approved". The surface is a review list.
//   2. Issuer-only facts (income, on-time payment history, account
//      age, hard-inquiry policy, issuer eligibility) are always
//      surfaced as `.issuerOnly` checks. The evaluator *never*
//      flips them to `.met`.
//   3. Any NomadFi-visible check that fails prevents the card from
//      rolling up to `.readyToReview`.

import Foundation

/// Pure evaluator for the readiness checklist.
enum CreditLimitReadinessEvaluator {

    /// Issuer-only facts that always appear as caveats. Copy avoids
    /// the banned vocabulary (no "guarantee", "approved", "will get
    /// a limit increase").
    private static let issuerOnlyChecks: [CreditLimitReadinessItem] = [
        CreditLimitReadinessItem(
            id: "income",
            title: "Income on file with your issuer",
            detail: "Only your issuer knows the income and expenses on file. Confirm those are current before asking for a review.",
            status: .issuerOnly
        ),
        CreditLimitReadinessItem(
            id: "payment_history",
            title: "On-time payment history with this issuer",
            detail: "Issuers weigh their own payment-history record. NomadFi cannot see past statements they already settled.",
            status: .issuerOnly
        ),
        CreditLimitReadinessItem(
            id: "account_age",
            title: "Account age with this issuer",
            detail: "Account age affects issuer-side review. Check the open date on your issuer's site.",
            status: .issuerOnly
        ),
        CreditLimitReadinessItem(
            id: "hard_inquiry_policy",
            title: "Issuer's hard-inquiry policy",
            detail: "Some issuers run a hard inquiry on a limit review, others don't. NomadFi cannot predict this — confirm with your issuer first.",
            status: .issuerOnly
        ),
        CreditLimitReadinessItem(
            id: "issuer_eligibility",
            title: "Issuer's eligibility rules",
            detail: "Issuers set their own eligibility rules for a limit review. NomadFi does not make an approval claim on your behalf.",
            status: .issuerOnly
        ),
    ]

    /// Global caveats always shown above the per-card list.
    static let defaultGlobalCaveats: [String] = [
        "NomadFi does not request credit-limit increases on your behalf. Any review happens with your issuer.",
        "Credit scoring is multi-factor. NomadFi cannot promise a specific credit-score outcome or a limit-increase approval.",
    ]

    // MARK: - Public API

    /// Produces the full checklist.
    ///
    /// - Parameters:
    ///   - assessments: Per-card output from the Credit Timing
    ///     engine. Already ordered by severity — we re-sort by
    ///     readiness so the most actionable card surfaces first.
    ///   - now: Evaluation moment the engine injected.
    static func evaluate(
        assessments: [CreditTimingCardAssessment],
        now: Date = .now
    ) -> CreditLimitReadinessChecklist {
        let summaries = assessments.map(makeSummary)
        let sorted = summaries.sorted(by: needsMoreEvidenceFirst)
        return CreditLimitReadinessChecklist(
            cardSummaries: sorted,
            globalCaveats: defaultGlobalCaveats,
            evaluatedAt: now
        )
    }

    // MARK: - Per-card rollup

    private static func makeSummary(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessCardSummary {
        var items: [CreditLimitReadinessItem] = []

        items.append(creditLimitItem(for: assessment))
        items.append(balanceSnapshotItem(for: assessment))
        items.append(snapshotFreshnessItem(for: assessment))
        items.append(statementCalendarItem(for: assessment))
        items.append(utilizationBandItem(for: assessment))
        items.append(nearLimitItem(for: assessment))

        items.append(contentsOf: issuerOnlyChecks)

        let nomadFiVisibleItems = items.prefix(6) // the six NomadFi-visible rows.
        let allNomadFiVisibleMet = nomadFiVisibleItems.allSatisfy { $0.status == .met }

        return CreditLimitReadinessCardSummary(
            id: "credit-limit-readiness-\(assessment.id)",
            accountName: assessment.accountName,
            institutionName: assessment.institutionName,
            currencyCode: assessment.currencyCode,
            summary: allNomadFiVisibleMet ? .readyToReview : .needsMoreEvidence,
            items: items
        )
    }

    // MARK: - Individual check builders

    private static func creditLimitItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        if assessment.creditLimit != nil {
            return CreditLimitReadinessItem(
                id: "credit_limit",
                title: "Credit limit entered",
                detail: "NomadFi needs the limit to evaluate utilization. It's on file.",
                status: .met
            )
        }
        return CreditLimitReadinessItem(
            id: "credit_limit",
            title: "Credit limit entered",
            detail: "Enter the credit limit in Settings → Financial Setup → Accounts so NomadFi can reason about utilization honestly.",
            status: .missing
        )
    }

    private static func balanceSnapshotItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        if assessment.currentBalance != nil {
            return CreditLimitReadinessItem(
                id: "balance_snapshot",
                title: "Current balance snapshot entered",
                detail: "NomadFi has a balance to compare against the limit.",
                status: .met
            )
        }
        return CreditLimitReadinessItem(
            id: "balance_snapshot",
            title: "Current balance snapshot entered",
            detail: "Enter a current balance snapshot — NomadFi never treats a missing balance as zero.",
            status: .missing
        )
    }

    private static func snapshotFreshnessItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        if assessment.currentBalance == nil {
            return CreditLimitReadinessItem(
                id: "snapshot_freshness",
                title: "Balance snapshot is fresh",
                detail: "No snapshot on file yet. Add one, then re-run this check.",
                status: .missing
            )
        }
        if assessment.snapshotIsStale {
            return CreditLimitReadinessItem(
                id: "snapshot_freshness",
                title: "Balance snapshot is fresh",
                detail: "Latest snapshot is past its freshness window. Refresh it before asking your issuer for a limit review.",
                status: .notMet
            )
        }
        return CreditLimitReadinessItem(
            id: "snapshot_freshness",
            title: "Balance snapshot is fresh",
            detail: "Snapshot is inside its freshness window.",
            status: .met
        )
    }

    private static func statementCalendarItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        if assessment.scheduleState == .confirmed {
            return CreditLimitReadinessItem(
                id: "statement_calendar",
                title: "Statement calendar confirmed",
                detail: "NomadFi can anchor paydown guidance to a real statement close date.",
                status: .met
            )
        }
        return CreditLimitReadinessItem(
            id: "statement_calendar",
            title: "Statement calendar confirmed",
            detail: "Confirm the statement calendar for this card in Settings → Credit Card Calendar so NomadFi can reason about timing.",
            status: .notMet
        )
    }

    private static func utilizationBandItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        guard let band = assessment.utilizationBand else {
            return CreditLimitReadinessItem(
                id: "utilization_band",
                title: "Utilization is inside a planning target",
                detail: "NomadFi needs both a limit and a balance to compute utilization.",
                status: .missing
            )
        }
        switch band {
        case .low, .planning:
            return CreditLimitReadinessItem(
                id: "utilization_band",
                title: "Utilization is inside a planning target",
                detail: "This card is inside the conservative planning band NomadFi uses for review readiness.",
                status: .met
            )
        case .elevated, .high, .nearLimit:
            return CreditLimitReadinessItem(
                id: "utilization_band",
                title: "Utilization is inside a planning target",
                detail: "Utilization is above a conservative planning target. Pay the balance down before asking your issuer for a limit review.",
                status: .notMet
            )
        }
    }

    private static func nearLimitItem(
        for assessment: CreditTimingCardAssessment
    ) -> CreditLimitReadinessItem {
        if assessment.ruling == .nearLimitAvoidMoreSpend
            || assessment.utilizationBand == .nearLimit {
            return CreditLimitReadinessItem(
                id: "no_near_limit",
                title: "No near-limit signal",
                detail: "Balance is near the credit limit on this card. Avoid more spend and bring the balance down first.",
                status: .notMet
            )
        }
        return CreditLimitReadinessItem(
            id: "no_near_limit",
            title: "No near-limit signal",
            detail: "NomadFi doesn't see a near-limit signal on this card.",
            status: .met
        )
    }

    // MARK: - Sorting

    /// Surfaces the actionable cards first, then cards that are
    /// ready to review. Stable alphabetical fallback so the order
    /// doesn't flap between runs.
    private static func needsMoreEvidenceFirst(
        _ lhs: CreditLimitReadinessCardSummary,
        _ rhs: CreditLimitReadinessCardSummary
    ) -> Bool {
        if lhs.summary != rhs.summary {
            return lhs.summary == .needsMoreEvidence
        }
        if lhs.institutionName != rhs.institutionName {
            return lhs.institutionName < rhs.institutionName
        }
        return lhs.accountName < rhs.accountName
    }
}
