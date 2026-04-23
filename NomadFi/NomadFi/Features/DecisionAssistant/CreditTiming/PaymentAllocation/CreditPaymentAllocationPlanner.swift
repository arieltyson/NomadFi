// CreditPaymentAllocationPlanner.swift
// NomadFi
//
// Pure, deterministic payment-allocation planner. Consumes the
// engine's per-card assessments and produces a
// ``CreditPaymentAllocationPlan``. Never persists anything, never
// converts across currencies, never promises a credit-score outcome
// or an issuer-side action like a credit-limit increase.
//
// Rules encoded here (pinned in tests):
//   1. Only cards whose ruling is `.payDownBeforeClose` or
//      `.nearLimitAvoidMoreSpend` are eligible for strong allocation.
//      Cards that already sit inside the conservative 30 % band never
//      need a paydown line — they still surface as blockers if a
//      budget is supplied so the user knows why the card isn't in the
//      plan.
//   2. A card is excluded from strong allocation when anything the
//      engine flagged would make the paydown number dishonest:
//      missing credit limit, missing balance, stale snapshot, or
//      unconfirmed statement calendar.
//   3. Lines are grouped by currency so a $200 payment is never
//      implicitly spread across USD and CAD cards.
//   4. Priority inside a group: near-limit before elevated, earlier
//      confirmed statement close before later close, higher
//      utilization before lower, then a stable alphabetical
//      institution/name fallback.
//   5. When the planner receives a budget, the budget is distributed
//      only across lines whose currency matches the budget's
//      currency. Every higher-priority line is filled to its
//      conservative target first; any remaining budget is then used
//      to move lines down toward the strong 10 % target in the same
//      priority order. The planner never allocates more than the
//      strong target for any line, and never returns a negative
//      remainder.

import Foundation

/// Deterministic allocation planner. Call ``plan(assessments:now:budget:)``.
enum CreditPaymentAllocationPlanner {

    // MARK: - Public API

    /// Builds a plan from the Credit Timing engine's per-card
    /// assessments. Pass `budget` to have the planner distribute a
    /// user-entered payment across eligible cards; otherwise the
    /// plan is a target sheet.
    static func plan(
        assessments: [CreditTimingCardAssessment],
        now: Date = .now,
        budget: CreditPaymentAllocationBudget? = nil
    ) -> CreditPaymentAllocationPlan {
        // Partition assessments into eligible lines and blockers.
        var eligibleLines: [CreditPaymentAllocationLine] = []
        var blockers: [CreditPaymentAllocationBlocker] = []

        for assessment in assessments {
            switch classify(assessment) {
            case .eligible(let line):
                eligibleLines.append(line)
            case .blocked(let blocker):
                blockers.append(blocker)
            case .notRelevant:
                break
            }
        }

        // Sort within each currency group, then distribute the budget
        // (if any) inside the matching group only.
        let grouped = Dictionary(grouping: eligibleLines, by: \.currencyCode)
        var orderedGroups: [CreditPaymentAllocationCurrencyGroup] = []

        for currencyCode in grouped.keys.sorted() {
            let raw = grouped[currencyCode] ?? []
            let sorted = raw.sorted(by: priorityLessThan)

            let prioritised = sorted.enumerated().map { index, line in
                line.with(priority: index)
            }

            let distributed: [CreditPaymentAllocationLine]
            if let budget, budget.currencyCode == currencyCode {
                distributed = distribute(budget: budget.amount, across: prioritised)
            } else {
                distributed = prioritised
            }

            let group = CreditPaymentAllocationCurrencyGroup(
                currencyCode: currencyCode,
                lines: distributed,
                totalPaydownToConservativeTarget: distributed
                    .compactMap(\.paydownToConservativeTarget)
                    .reduce(0, +),
                totalPaydownToStrongTarget: distributed
                    .compactMap(\.paydownToStrongTarget)
                    .reduce(0, +),
                suggestedTotalPayment: distributed
                    .compactMap(\.suggestedPayment)
                    .reduce(0, +)
            )
            orderedGroups.append(group)
        }

        return CreditPaymentAllocationPlan(
            groups: orderedGroups,
            blockers: blockers.sorted(by: blockerStableOrder),
            appliedBudget: budget,
            evaluatedAt: now
        )
    }

    // MARK: - Classification

    private enum Classification {
        case eligible(CreditPaymentAllocationLine)
        case blocked(CreditPaymentAllocationBlocker)
        case notRelevant
    }

    private static func classify(
        _ assessment: CreditTimingCardAssessment
    ) -> Classification {
        // Hard blockers first — same order as the engine's ruling
        // precedence so the user gets a consistent narrative.
        if assessment.creditLimit == nil {
            return .blocked(makeBlocker(assessment, reason: .missingCreditLimit))
        }
        if assessment.currentBalance == nil {
            return .blocked(makeBlocker(assessment, reason: .missingBalanceSnapshot))
        }
        if assessment.snapshotIsStale {
            return .blocked(makeBlocker(assessment, reason: .staleSnapshot))
        }
        if assessment.scheduleState != .confirmed {
            return .blocked(makeBlocker(assessment, reason: .unconfirmedSchedule))
        }

        // Eligibility: ruling must be one of the two "act on me"
        // rulings. Anything else (ready, needsSetup, stale, missing
        // schedule) either produces no plan line or was already
        // captured above as a blocker.
        switch assessment.ruling {
        case .payDownBeforeClose, .nearLimitAvoidMoreSpend:
            break
        case .readyNoUrgentAction:
            // Card is already at or below the conservative target —
            // surface as a blocker so the user sees we acknowledged it.
            return .blocked(makeBlocker(assessment, reason: .belowConservativeTarget))
        case .needsSetup, .snapshotStale, .scheduleMissing:
            // These were caught above as blockers. Defensive fall-through.
            return .notRelevant
        }

        // Require a conservative paydown number — otherwise there's
        // nothing to plan against.
        guard let conservativePaydown = assessment.paydownTargetTo30Percent,
              conservativePaydown > 0 else {
            return .blocked(makeBlocker(assessment, reason: .belowConservativeTarget))
        }

        let reason = planReason(for: assessment)
        let line = CreditPaymentAllocationLine(
            id: assessment.id,
            accountName: assessment.accountName,
            institutionName: assessment.institutionName,
            currencyCode: assessment.currencyCode,
            priority: 0, // filled after sort
            ruling: assessment.ruling,
            utilization: assessment.utilization,
            paydownToConservativeTarget: conservativePaydown,
            paydownToStrongTarget: assessment.paydownTargetTo10Percent,
            suggestedPayment: nil,
            statementClosingDate: assessment.statementClosingDate,
            reason: reason
        )
        return .eligible(line)
    }

    private static func makeBlocker(
        _ assessment: CreditTimingCardAssessment,
        reason: CreditPaymentAllocationBlockerReason
    ) -> CreditPaymentAllocationBlocker {
        CreditPaymentAllocationBlocker(
            id: assessment.id,
            accountName: assessment.accountName,
            institutionName: assessment.institutionName,
            reason: reason
        )
    }

    private static func planReason(
        for assessment: CreditTimingCardAssessment
    ) -> String {
        switch assessment.ruling {
        case .nearLimitAvoidMoreSpend:
            return "Balance is near the credit limit on this card."
        case .payDownBeforeClose:
            if let band = assessment.utilizationBand, band == .high {
                return "Balance would report well above a conservative planning target."
            }
            return "Balance would report above a conservative planning target."
        default:
            return "Balance is above a conservative planning target."
        }
    }

    // MARK: - Priority sort

    /// Rule 4: near-limit wins, earlier statement close next, higher
    /// utilization next, then stable alphabetical fallback.
    private static func priorityLessThan(
        _ lhs: CreditPaymentAllocationLine,
        _ rhs: CreditPaymentAllocationLine
    ) -> Bool {
        let lhsRank = rulingRank(lhs.ruling)
        let rhsRank = rulingRank(rhs.ruling)
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        switch (lhs.statementClosingDate, rhs.statementClosingDate) {
        case let (l?, r?) where l != r:
            return l < r
        case (nil, _?):
            // A card without a close date shouldn't have been
            // eligible (schedule unconfirmed = blocker), but guard
            // against it anyway.
            return false
        case (_?, nil):
            return true
        default:
            break
        }

        switch (lhs.utilization, rhs.utilization) {
        case let (l?, r?) where l != r:
            return l > r
        default:
            break
        }

        if lhs.institutionName != rhs.institutionName {
            return lhs.institutionName < rhs.institutionName
        }
        return lhs.accountName < rhs.accountName
    }

    private static func rulingRank(
        _ ruling: CreditTimingCardRuling
    ) -> Int {
        switch ruling {
        case .nearLimitAvoidMoreSpend: 0
        case .payDownBeforeClose: 1
        default: 9 // shouldn't reach here for eligible lines
        }
    }

    // MARK: - Budget distribution

    /// Fills every higher-priority line to its conservative target
    /// first, then returns any remainder to push lines toward the
    /// stronger 10 % target in the same priority order. Never
    /// overshoots the strong target on a given line.
    private static func distribute(
        budget total: Double,
        across lines: [CreditPaymentAllocationLine]
    ) -> [CreditPaymentAllocationLine] {
        guard total > 0 else {
            return lines.map { $0.with(suggestedPayment: 0) }
        }

        var remaining = total
        var suggestions: [Double] = Array(repeating: 0, count: lines.count)

        // Pass 1 — fill conservative targets in priority order.
        for index in lines.indices {
            guard remaining > 0 else { break }
            let conservative = lines[index].paydownToConservativeTarget ?? 0
            let take = min(conservative, remaining)
            suggestions[index] += take
            remaining -= take
        }

        // Pass 2 — if the user over-funded pass 1, keep pushing into
        // the strong target on the same priority order, but never
        // exceed the per-line strong target.
        if remaining > 0 {
            for index in lines.indices {
                guard remaining > 0 else { break }
                let strong = lines[index].paydownToStrongTarget ?? 0
                let already = suggestions[index]
                let headroom = max(0, strong - already)
                let take = min(headroom, remaining)
                suggestions[index] += take
                remaining -= take
            }
        }

        // If we still have remainder, the user over-funded the plan
        // — NomadFi returns it unused rather than inventing a new
        // target to silently consume it.
        return zip(lines.indices, lines).map { index, line in
            line.with(suggestedPayment: suggestions[index])
        }
    }

    // MARK: - Blocker ordering

    private static func blockerStableOrder(
        _ lhs: CreditPaymentAllocationBlocker,
        _ rhs: CreditPaymentAllocationBlocker
    ) -> Bool {
        if lhs.institutionName != rhs.institutionName {
            return lhs.institutionName < rhs.institutionName
        }
        return lhs.accountName < rhs.accountName
    }
}

// MARK: - Line mutators

private extension CreditPaymentAllocationLine {
    func with(priority newPriority: Int) -> CreditPaymentAllocationLine {
        CreditPaymentAllocationLine(
            id: id,
            accountName: accountName,
            institutionName: institutionName,
            currencyCode: currencyCode,
            priority: newPriority,
            ruling: ruling,
            utilization: utilization,
            paydownToConservativeTarget: paydownToConservativeTarget,
            paydownToStrongTarget: paydownToStrongTarget,
            suggestedPayment: suggestedPayment,
            statementClosingDate: statementClosingDate,
            reason: reason
        )
    }

    func with(suggestedPayment value: Double?) -> CreditPaymentAllocationLine {
        CreditPaymentAllocationLine(
            id: id,
            accountName: accountName,
            institutionName: institutionName,
            currencyCode: currencyCode,
            priority: priority,
            ruling: ruling,
            utilization: utilization,
            paydownToConservativeTarget: paydownToConservativeTarget,
            paydownToStrongTarget: paydownToStrongTarget,
            suggestedPayment: value,
            statementClosingDate: statementClosingDate,
            reason: reason
        )
    }
}
