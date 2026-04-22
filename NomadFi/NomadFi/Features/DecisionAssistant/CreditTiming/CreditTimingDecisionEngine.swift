// CreditTimingDecisionEngine.swift
// NomadFi
//
// Pure, testable engine behind the Credit Timing decision brief.
// Consumes the user's `Account` rows (filtered to credit cards) and
// their attached `CreditCardSchedule`s, and produces a
// ``CreditTimingDecision``.
//
// Source anchors (see docs/MISSION.md and the citation catalog):
//   - CFPB: credit scores are multi-factor and cannot be guaranteed
//     by any single action.
//   - CFPB: paying the statement balance in full by the due date is
//     how users avoid interest without carrying a balance.
//   - myFICO: "Amounts Owed" (including utilization) is roughly 30%
//     of a FICO Score — an input, not a deterministic score driver.
//   - myFICO: issuers generally report the statement balance, so
//     paying before close is how a user influences the *reported*
//     balance.
//
// Hard rules encoded here:
//   - Nil values are never treated as zero.
//   - A stale snapshot never yields a strong ruling.
//   - An unconfirmed schedule never yields a strong ruling.
//   - Copy never uses "guarantee", "score will increase", "carry a
//     balance", or any absolute outcome language.
//   - All dates surface as absolute dates; no relative phrasing.

import Foundation

/// The deterministic Credit Timing engine.
///
/// Stateless namespace — everything is a pure function of the inputs.
/// Call ``decide(accounts:now:)`` to produce the full decision.
enum CreditTimingDecisionEngine {

    // MARK: - Thresholds

    /// Conservative planning threshold (≈30%). Used to compute the
    /// paydown amount needed to move a card out of the elevated/high
    /// bands before statement close.
    static let conservativePlanningThreshold: Double = 0.30

    /// Stronger planning target (≈10%). Offered as an optional lower
    /// target — NomadFi never claims hitting it guarantees a score
    /// outcome.
    static let strongPlanningThreshold: Double = 0.10

    // MARK: - Hard rules

    /// Non-negotiable guidance surfaced on every brief. Pinned here
    /// so the UI always shows them, regardless of engine output.
    static let hardRules: [String] = [
        "Always pay at least the statement balance by the due date. NomadFi never recommends carrying a balance.",
        "Credit scoring is multi-factor. NomadFi cannot promise a specific score outcome from any single action.",
        "Use absolute dates when planning — never rely on a relative phrase like \"soon\" or \"in a few days\".",
    ]

    // MARK: - Public API

    /// Produces the full Credit Timing decision for the supplied
    /// accounts.
    ///
    /// - Parameters:
    ///   - accounts: Every `Account` SwiftData owns. The engine
    ///     filters to credit cards itself so callers don't need to
    ///     pre-filter.
    ///   - now: Injection point for the current moment. Lets tests
    ///     pin staleness boundaries and schedule anchors.
    static func decide(
        accounts: [Account],
        now: Date = .now
    ) -> CreditTimingDecision {
        let creditCards = accounts.filter(\.isCreditCard)

        guard !creditCards.isEmpty else {
            return CreditTimingDecision(
                ruling: .noCreditCardsOnFile,
                cardAssessments: [],
                missingDataChecklist: [
                    "Add a credit-card account in Settings → Financial Setup → Accounts.",
                ],
                hardRules: hardRules,
                citations: CreditTimingCitationCatalog.creditTiming,
                evaluatedAt: now
            )
        }

        let assessments = creditCards
            .map { assess($0, now: now) }
            .sorted(by: severityDescending)

        let aggregatedChecks = aggregateChecks(from: assessments)
        let ruling = topLevelRuling(for: assessments)

        return CreditTimingDecision(
            ruling: ruling,
            cardAssessments: assessments,
            missingDataChecklist: aggregatedChecks,
            hardRules: hardRules,
            citations: CreditTimingCitationCatalog.creditTiming,
            evaluatedAt: now
        )
    }
}

// MARK: - Per-card assessment

private extension CreditTimingDecisionEngine {

    static func assess(
        _ account: Account,
        now: Date
    ) -> CreditTimingCardAssessment {
        let schedule = CreditCardSchedule(account: account)
        let scheduleState = schedule.state

        let utilization = computedUtilization(for: account)
        let band = utilization.map(CreditTimingUtilizationBand.band(for:))

        let snapshotIsStale = account.hasFinancialSnapshot
            && account.isFinancialSnapshotStale(now: now)

        let ruling = cardRuling(
            account: account,
            utilization: utilization,
            band: band,
            scheduleState: scheduleState,
            snapshotIsStale: snapshotIsStale
        )

        let paydownTo30 = paydownAmount(
            balance: account.currentBalance,
            limit: account.creditLimit,
            toTarget: conservativePlanningThreshold
        )
        let paydownTo10 = paydownAmount(
            balance: account.currentBalance,
            limit: account.creditLimit,
            toTarget: strongPlanningThreshold
        )

        return CreditTimingCardAssessment(
            id: identifier(for: account),
            accountName: account.name,
            institutionName: account.institutionName,
            currencyCode: account.currencyCodeRawValue,
            ruling: ruling,
            utilization: utilization,
            utilizationBand: band,
            currentBalance: account.currentBalance,
            creditLimit: account.creditLimit,
            statementClosingDate: account.statementClosingDate,
            paymentDueDate: account.paymentDueDate,
            snapshotUpdatedAt: account.financialSnapshotUpdatedAt,
            snapshotIsStale: snapshotIsStale,
            scheduleState: scheduleState,
            paydownTargetTo30Percent: paydownTo30,
            paydownTargetTo10Percent: paydownTo10,
            outstandingChecks: outstandingChecks(
                for: account,
                scheduleState: scheduleState,
                snapshotIsStale: snapshotIsStale
            )
        )
    }

    /// Returns the `currentBalance / creditLimit` ratio when both
    /// inputs are known and the limit is strictly positive. `nil`
    /// otherwise. Never treats a nil balance as zero — an unknown
    /// balance is unknown, full stop.
    static func computedUtilization(for account: Account) -> Double? {
        guard let limit = account.creditLimit, limit > 0 else {
            return nil
        }
        guard let balance = account.currentBalance else {
            return nil
        }
        return balance / limit
    }

    static func cardRuling(
        account: Account,
        utilization: Double?,
        band: CreditTimingUtilizationBand?,
        scheduleState: CreditCardScheduleState,
        snapshotIsStale: Bool
    ) -> CreditTimingCardRuling {
        // Missing setup (limit or balance) always wins — without those
        // the engine refuses to reason about utilization.
        if account.creditLimit == nil || account.currentBalance == nil {
            return .needsSetup
        }

        if snapshotIsStale {
            return .snapshotStale
        }

        if scheduleState != .confirmed {
            return .scheduleMissing
        }

        guard let band else {
            // Safety net — shouldn't hit because the above checks
            // would have returned, but we'd rather say "needsSetup"
            // than a strong recommendation if the math went wrong.
            return .needsSetup
        }

        switch band {
        case .low, .planning:
            return .readyNoUrgentAction
        case .elevated, .high:
            return .payDownBeforeClose
        case .nearLimit:
            return .nearLimitAvoidMoreSpend
        }
    }

    /// Amount to pay to land reported utilization at roughly
    /// ``toTarget``. Returns `nil` when inputs are missing or when
    /// the current balance is already at or below the target.
    static func paydownAmount(
        balance: Double?,
        limit: Double?,
        toTarget target: Double
    ) -> Double? {
        guard let balance, let limit, limit > 0 else { return nil }
        let targetBalance = target * limit
        let paydown = balance - targetBalance
        return paydown > 0 ? paydown : nil
    }

    /// Per-card missing-data checks. Each entry is user-actionable.
    static func outstandingChecks(
        for account: Account,
        scheduleState: CreditCardScheduleState,
        snapshotIsStale: Bool
    ) -> [String] {
        var checks: [String] = []
        let name = displayName(for: account)

        if account.creditLimit == nil {
            checks.append("Enter the credit limit for \(name) in Settings → Financial Setup → Accounts.")
        }
        if account.currentBalance == nil {
            checks.append("Enter a current balance snapshot for \(name).")
        }
        if snapshotIsStale {
            checks.append("Refresh the balance snapshot for \(name) — the last one is past its freshness window.")
        }
        switch scheduleState {
        case .missing:
            checks.append("Add the statement calendar for \(name) in Settings → Credit Card Calendar.")
        case .partial:
            checks.append("Complete the statement calendar for \(name) in Settings → Credit Card Calendar.")
        case .needsAttention:
            checks.append("Review the statement calendar for \(name) — the dates aren't in a valid order.")
        case .confirmed:
            break
        }
        return checks
    }

    // MARK: Aggregation

    /// Portfolio-level ruling from the per-card rulings. Severity
    /// order: nearLimit > payDown > missingData (any needsSetup /
    /// stale / scheduleMissing) > ready.
    static func topLevelRuling(
        for assessments: [CreditTimingCardAssessment]
    ) -> CreditTimingRuling {
        if assessments.isEmpty { return .noCreditCardsOnFile }

        let rulings = Set(assessments.map(\.ruling))
        if rulings.contains(.nearLimitAvoidMoreSpend) {
            return .someNearLimit
        }
        if rulings.contains(.payDownBeforeClose) {
            return .somePayDownBeforeClose
        }
        if rulings.contains(.needsSetup)
            || rulings.contains(.snapshotStale)
            || rulings.contains(.scheduleMissing) {
            return .missingData
        }
        return .allCardsReady
    }

    /// De-duplicated checklist from every card, preserving per-card
    /// order of appearance so the user reads a sensible narrative.
    static func aggregateChecks(
        from assessments: [CreditTimingCardAssessment]
    ) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for assessment in assessments {
            for check in assessment.outstandingChecks where seen.insert(check).inserted {
                ordered.append(check)
            }
        }
        return ordered
    }

    // MARK: Sorting

    /// Stable severity ranking so the most urgent card renders first
    /// in the brief sheet.
    static func severityRank(_ ruling: CreditTimingCardRuling) -> Int {
        switch ruling {
        case .nearLimitAvoidMoreSpend: 0
        case .payDownBeforeClose: 1
        case .needsSetup: 2
        case .snapshotStale: 3
        case .scheduleMissing: 4
        case .readyNoUrgentAction: 5
        }
    }

    static func severityDescending(
        _ lhs: CreditTimingCardAssessment,
        _ rhs: CreditTimingCardAssessment
    ) -> Bool {
        let lhsRank = severityRank(lhs.ruling)
        let rhsRank = severityRank(rhs.ruling)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        // Same severity: fall back to a stable alphabetical order so
        // the sort never flaps between runs.
        if lhs.institutionName == rhs.institutionName {
            return lhs.accountName < rhs.accountName
        }
        return lhs.institutionName < rhs.institutionName
    }

    // MARK: Identity + display

    static func identifier(for account: Account) -> String {
        let institution = account.institutionName.isEmpty
            ? "unknown-issuer"
            : account.institutionName
        let name = account.name.isEmpty ? "unnamed-card" : account.name
        return "credit-timing-\(institution)-\(name)"
    }

    static func displayName(for account: Account) -> String {
        let name = account.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let institution = account.institutionName.trimmingCharacters(in: .whitespaces)
        if !institution.isEmpty { return institution }
        return "this card"
    }
}
