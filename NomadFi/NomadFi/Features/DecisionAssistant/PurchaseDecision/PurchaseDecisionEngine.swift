// PurchaseDecisionEngine.swift
// NomadFi
//
// Pure, testable engine behind the generic purchase decision brief.
// Consumes a `PurchaseContext` (merchant, category, amount,
// currency, country, timing) + the user's `[Account]` rows and
// produces a `PurchaseDecision` — one recommended payment method, a
// fallback, and caveated / blocked candidates.
//
// Hard invariants pinned in code and in tests:
//   - Nil balances are never treated as zero.
//   - Investment accounts are never payment methods.
//   - A stale snapshot never produces a strong recommendation.
//   - Rewards are never used for ranking in v1 — NomadFi has no
//     verified rewards data yet, and the copy says so.
//   - The engine never claims a credit-score or limit-increase
//     outcome and never recommends carrying a balance.
//   - All user-facing dates are absolute (no "soon", no "today").

import Foundation

/// The deterministic generic purchase engine.
enum PurchaseDecisionEngine {

    // MARK: - Thresholds

    /// Conservative projected-utilization cap the engine uses to
    /// decide whether a credit card should be promoted to
    /// ``PurchaseCandidateStance/recommended`` vs. demoted to
    /// ``PurchaseCandidateStance/usableWithCaveats``.
    static let conservativeProjectedUtilization: Double = 0.30

    // MARK: - Hard rules

    static let hardRules: [String] = [
        "Always pay the statement balance in full by the due date. NomadFi never recommends carrying a balance or taking a cash advance for rewards.",
        "Credit scoring is multi-factor. NomadFi cannot promise a specific credit-score outcome from any single purchase decision.",
        "Rewards are used only when a verified source is on file and still inside its freshness window, and only when the unit is comparable across candidates. Unverified or stale rates are shown as context and never drive ranking.",
        "NomadFi never guarantees card acceptance, credit-limit increases, or that any method will be the cheapest in every future cycle.",
    ]

    // MARK: - Public API

    /// Produces the full purchase decision for the supplied context
    /// and account list.
    static func decide(
        context: PurchaseContext,
        accounts: [Account],
        now: Date = .now
    ) -> PurchaseDecision {
        // Always run per-account filtering so the UI can surface
        // excluded investment rows even when the amount is missing.
        let raw = accounts.map {
            assess($0, context: context, now: now)
        }

        let sorted = raw.sorted(by: severityDescending)

        // When the purchase is not usable yet, the engine refuses to
        // pick a winner even if candidates exist. Every usable
        // candidate is demoted to `.usableWithCaveats` so the UI can
        // still show the user what their options look like once they
        // fill in the amount.
        let decorated = decorate(
            candidates: sorted,
            contextIsUsable: context.hasUsableAmount
        )

        let ruling = topLevelRuling(
            candidates: decorated,
            context: context
        )

        let recommendation = decorated.first { $0.stance == .recommended }
        let fallback = decorated.first { $0.stance == .fallback }

        // Phase 3 follow-through — derive cross-border / travel
        // signals from inputs we already have, so DCC, FX, and
        // dispute-process caveats only fire when the context warrants.
        let travelContext = PurchaseTravelContext.from(
            context: context,
            accountCurrencies: accounts.map(\.currencyCodeRawValue)
        )

        let checks = aggregatedChecks(
            candidates: decorated,
            context: context,
            travelContext: travelContext
        )

        let warningList = warnings(
            for: recommendation,
            fallback: fallback,
            context: context,
            travelContext: travelContext
        )

        let confidenceResult = derivedConfidence(
            recommendation: recommendation,
            outstandingCheckCount: checks.count,
            travelContext: travelContext
        )

        return PurchaseDecision(
            context: context,
            ruling: ruling,
            recommendation: recommendation,
            fallback: fallback,
            candidates: decorated,
            whenNotToUseWarnings: warningList,
            missingDataChecklist: checks,
            hardRules: hardRules,
            citations: PurchaseDecisionCitationCatalog.purchaseDecision,
            evaluatedAt: now,
            travelContext: travelContext,
            confidence: confidenceResult.label,
            confidenceExplanations: confidenceResult.explanations
        )
    }
}

// MARK: - Per-account assessment

private extension PurchaseDecisionEngine {

    static func assess(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        if account.accountType == .investment {
            return baseAssessment(
                account,
                stance: .excludedInvestment,
                reasons: [
                    "Investment accounts are not a payment method in NomadFi.",
                ],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        if account.isCreditCard {
            return assessCreditCard(account, context: context, now: now)
        }

        return assessDeposit(account, context: context, now: now)
    }

    static func assessCreditCard(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let displayName = accountDisplayName(for: account)

        // Setup gate: without a limit or a current balance the engine
        // refuses to reason about this card.
        if account.creditLimit == nil || account.currentBalance == nil {
            let missing = missingCreditCardSetupChecks(for: account, displayName: displayName)
            return baseAssessment(
                account,
                stance: .needsSetup,
                reasons: ["Missing credit limit or current balance on this card."],
                outstandingChecks: missing,
                context: context,
                now: now
            )
        }

        let snapshotIsStale = account.hasFinancialSnapshot
            && account.isFinancialSnapshotStale(now: now)

        if snapshotIsStale {
            return baseAssessment(
                account,
                stance: .snapshotStale,
                reasons: ["Latest balance snapshot is past its freshness window — no strong recommendation."],
                outstandingChecks: [
                    "Refresh the balance snapshot for \(displayName) in Settings → Financial Setup → Accounts.",
                ],
                context: context,
                now: now
            )
        }

        // Coverage check — only meaningful when currencies match; a
        // cross-currency amount compared against a same-currency
        // available credit would be a unit error. Flag the FX case
        // as a caveat instead of a blocker.
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        let projectedAvailableCredit = projectedAvailableCredit(for: account)

        if sameCurrency,
           let purchaseAmount = context.amount,
           purchaseAmount > 0,
           let projected = projectedAvailableCredit,
           projected < purchaseAmount {
            return baseAssessment(
                account,
                stance: .insufficientCreditCoverage,
                reasons: [
                    "Available credit on this card is below the purchase amount.",
                ],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        var reasons: [String] = []
        var checks: [String] = []

        // Projected utilization messaging — only when we have enough
        // signal to compute it honestly.
        if sameCurrency, let purchaseAmount = context.amount,
           let limit = account.creditLimit, limit > 0,
           let balance = account.currentBalance {
            let projectedUtil = (balance + purchaseAmount) / limit
            if projectedUtil > conservativeProjectedUtilization {
                let percent = (projectedUtil * 100)
                    .formatted(.number.precision(.fractionLength(1)))
                reasons.append(
                    "Projected utilization after this purchase is ≈ \(percent)% — above NomadFi's conservative planning target."
                )
            }
        }

        // Schedule signal.
        let schedule = CreditCardSchedule(account: account)
        switch schedule.state {
        case .confirmed:
            if let closing = schedule.statementClosingDate {
                let formatted = closing.formatted(
                    .dateTime.year().month(.wide).day()
                )
                reasons.append(
                    "Confirmed statement calendar — statement closes \(formatted). Pay the statement balance by the due date."
                )
            }
        case .partial:
            checks.append(
                "Complete the statement calendar for \(displayName) in Settings → Credit Card Calendar."
            )
            reasons.append("Statement calendar is not fully confirmed.")
        case .missing:
            checks.append(
                "Add the statement calendar for \(displayName) in Settings → Credit Card Calendar."
            )
            reasons.append("No statement calendar on file.")
        case .needsAttention:
            checks.append(
                "Review the statement calendar for \(displayName) — the dates aren't in a valid order."
            )
            reasons.append("Statement calendar dates need attention.")
        }

        // FX signal.
        let fxInfo = foreignTransactionInfo(
            account: account,
            context: context,
            now: now
        )
        if let note = fxInfo.reason {
            reasons.append(note)
        }
        checks.append(contentsOf: fxInfo.checks)

        // Reward signal. The engine only factors rewards into
        // ranking when verified + fresh + unit-comparable; here we
        // just surface the narrative explanation on the per-card
        // row so the UI and voice surface can read it back honestly.
        let rewardEvaluation = account.evaluateReward(
            for: context.category,
            now: now
        )
        if let rewardExplanation = rewardEvaluation.explanation {
            reasons.append(rewardExplanation)
        }
        if rewardEvaluation.rate != nil, !rewardEvaluation.isVerifiedAndFresh {
            checks.append(
                "Verify reward terms on \(displayName) against the issuer's current product page and stamp the source in Settings."
            )
        }

        // Decide on stance: if schedule confirmed + coverage OK + no
        // hard caveat, we consider this a candidate. The picker in
        // `decorate(candidates:)` will promote exactly one as
        // `.recommended` and one as `.fallback`.
        let stance: PurchaseCandidateStance = .usableWithCaveats

        return finalAssessment(
            account,
            stance: stance,
            reasons: reasons,
            outstandingChecks: checks,
            context: context,
            fxInfo: fxInfo,
            now: now
        )
    }

    static func assessDeposit(
        _ account: Account,
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let displayName = accountDisplayName(for: account)
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        let availableFunds = account.latestBalanceForDisplay

        if availableFunds == nil {
            return baseAssessment(
                account,
                stance: .needsSetup,
                reasons: ["No current balance on file for this account."],
                outstandingChecks: [
                    "Enter a current balance snapshot for \(displayName) in Settings → Financial Setup → Accounts.",
                ],
                context: context,
                now: now
            )
        }

        if sameCurrency,
           let purchaseAmount = context.amount,
           purchaseAmount > 0,
           let funds = availableFunds,
           funds < purchaseAmount {
            return baseAssessment(
                account,
                stance: .insufficientFunds,
                reasons: ["Known balance is below the purchase amount."],
                outstandingChecks: [],
                context: context,
                now: now
            )
        }

        var reasons: [String] = []
        var checks: [String] = []

        let fxInfo = foreignTransactionInfo(
            account: account,
            context: context,
            now: now
        )
        if let note = fxInfo.reason {
            reasons.append(note)
        }
        checks.append(contentsOf: fxInfo.checks)

        return finalAssessment(
            account,
            stance: .usableWithCaveats,
            reasons: reasons,
            outstandingChecks: checks,
            context: context,
            fxInfo: fxInfo,
            now: now
        )
    }

    // MARK: - Helpers

    static func missingCreditCardSetupChecks(
        for account: Account,
        displayName: String
    ) -> [String] {
        var checks: [String] = []
        if account.creditLimit == nil {
            checks.append(
                "Enter the credit limit for \(displayName) in Settings → Financial Setup → Accounts."
            )
        }
        if account.currentBalance == nil {
            checks.append(
                "Enter a current balance snapshot for \(displayName)."
            )
        }
        return checks
    }

    static func projectedAvailableCredit(for account: Account) -> Double? {
        if let explicit = account.availableCredit {
            return explicit
        }
        guard let limit = account.creditLimit,
              let balance = account.currentBalance
        else {
            return nil
        }
        let computed = limit - balance
        return computed > 0 ? computed : 0
    }

    struct ForeignTransactionInfo: Sendable, Equatable {
        let feePercent: Double?
        let isVerified: Bool
        let reason: String?
        let checks: [String]
    }

    static func foreignTransactionInfo(
        account: Account,
        context: PurchaseContext,
        now: Date
    ) -> ForeignTransactionInfo {
        let matches = account.currencyCodeRawValue == context.currencyCode.rawValue
        guard !matches else {
            return ForeignTransactionInfo(
                feePercent: nil,
                isVerified: true,
                reason: nil,
                checks: []
            )
        }

        let provenance = account.foreignTransactionFeeProvenance
        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms,
            now: now
        )
        let isVerified = effective.isVerified

        let displayName = accountDisplayName(for: account)
        let feePercent = account.foreignTransactionFeePercent
        let formattedFee = feePercent.formatted(
            .number.precision(.fractionLength(1))
        )

        let reason: String
        if isVerified {
            reason = "Foreign-transaction fee on this account is \(formattedFee)% — converted via issuer terms. Verify the final amount against your issuer's current page."
        } else {
            reason = "NomadFi has an unverified foreign-transaction fee on this account. FX conversion needs verification before treating this as a firm cost."
        }

        var checks: [String] = []
        checks.append(
            "Verify the foreign-currency conversion and any card acceptance for \(displayName) on the issuer's current product page or cardmember agreement."
        )
        return ForeignTransactionInfo(
            feePercent: feePercent,
            isVerified: isVerified,
            reason: reason,
            checks: checks
        )
    }

    static func baseAssessment(
        _ account: Account,
        stance: PurchaseCandidateStance,
        reasons: [String],
        outstandingChecks: [String],
        context: PurchaseContext,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        return PurchaseCandidateAssessment(
            id: identifier(for: account),
            accountName: accountDisplayName(for: account),
            institutionName: account.institutionName,
            accountTypeDisplay: account.accountType?.displayName ?? "Account",
            currencyCode: account.currencyCodeRawValue,
            matchesPurchaseCurrency: sameCurrency,
            stance: stance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: account.currentBalance ?? account.latestBalanceForDisplay,
            creditLimit: account.creditLimit,
            availableCredit: projectedAvailableCredit(for: account),
            isCreditCard: account.isCreditCard,
            foreignTransactionFeePercent: nil,
            foreignTransactionFeeIsVerified: sameCurrency,
            rewardEvaluation: rewardEvaluation(for: account, context: context, now: now)
        )
    }

    static func finalAssessment(
        _ account: Account,
        stance: PurchaseCandidateStance,
        reasons: [String],
        outstandingChecks: [String],
        context: PurchaseContext,
        fxInfo: ForeignTransactionInfo,
        now: Date
    ) -> PurchaseCandidateAssessment {
        let sameCurrency = account.currencyCodeRawValue == context.currencyCode.rawValue
        return PurchaseCandidateAssessment(
            id: identifier(for: account),
            accountName: accountDisplayName(for: account),
            institutionName: account.institutionName,
            accountTypeDisplay: account.accountType?.displayName ?? "Account",
            currencyCode: account.currencyCodeRawValue,
            matchesPurchaseCurrency: sameCurrency,
            stance: stance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: account.currentBalance ?? account.latestBalanceForDisplay,
            creditLimit: account.creditLimit,
            availableCredit: projectedAvailableCredit(for: account),
            isCreditCard: account.isCreditCard,
            foreignTransactionFeePercent: fxInfo.feePercent,
            foreignTransactionFeeIsVerified: fxInfo.isVerified,
            rewardEvaluation: rewardEvaluation(for: account, context: context, now: now)
        )
    }

    /// Evaluate the account's rewards for the purchase. Deposit and
    /// non-credit-card accounts always get an empty evaluation —
    /// NomadFi does not model debit-card rewards in v1.
    static func rewardEvaluation(
        for account: Account,
        context: PurchaseContext,
        now: Date
    ) -> RewardRateEvaluation {
        guard account.isCreditCard else { return .empty }
        return account.evaluateReward(for: context.category, now: now)
    }

    // MARK: - Ranking

    /// Score tuple for ranking usable candidates. Lower is better.
    ///
    /// Ordering (decreasing priority):
    ///   1. Same-currency accounts beat cross-currency ones.
    ///   2. Credit cards with a fully verified FX fee beat ones with
    ///      an unverified FX fee.
    ///   3. Verified + comparable reward rate (see
    ///      ``rewardAdvantageScore(_:amongComparableUnit:)``).
    ///      Zero when rewards can't be compared, so this tier is a
    ///      no-op and the ranking falls through unchanged.
    ///   4. Non-credit (deposit / wallet) beats credit card — NomadFi
    ///      avoids promoting debt-risk paths over pay-now-from-funds
    ///      paths when rewards don't differentiate them.
    ///   5. Stable tiebreaker: institution + account name.
    ///
    /// The numeric `Int` values follow "lower is better" so Swift's
    /// default tuple comparison picks the expected winner without
    /// custom comparators.
    static func rankingScore(
        _ assessment: PurchaseCandidateAssessment,
        comparableRewardUnit: RewardUnit?
    ) -> (Int, Int, Int, Int, String, String) {
        let currencyScore = assessment.matchesPurchaseCurrency ? 0 : 1
        let fxVerifiedScore = assessment.foreignTransactionFeeIsVerified ? 0 : 1
        let rewardScore = rewardAdvantageScore(
            assessment,
            amongComparableUnit: comparableRewardUnit
        )
        let debtRiskScore = assessment.isCreditCard ? 1 : 0
        return (
            currencyScore,
            fxVerifiedScore,
            rewardScore,
            debtRiskScore,
            assessment.institutionName,
            assessment.accountName
        )
    }

    /// Negative integer reward score used by ``rankingScore`` —
    /// smaller (more negative) is better, matching the
    /// "lower is better" contract the tuple comparator relies on.
    ///
    /// Returns 0 when:
    ///   - the assessment has no usable reward signal (missing rate,
    ///     unverified, stale, unknown unit), OR
    ///   - the unit doesn't match the comparable-unit argument
    ///     (rewards are apples-to-oranges across the usable set, so
    ///     we refuse to rank on them).
    static func rewardAdvantageScore(
        _ assessment: PurchaseCandidateAssessment,
        amongComparableUnit comparableUnit: RewardUnit?
    ) -> Int {
        let evaluation = assessment.rewardEvaluation
        guard evaluation.isUsableForRanking,
              let rate = evaluation.rate,
              let comparableUnit,
              evaluation.unit == comparableUnit
        else {
            return 0
        }
        // Multiply by -100 so "2.5%" → -250, "1.25%" → -125.
        // Integer values keep tuple comparison deterministic.
        return Int((-rate * 100).rounded())
    }

    /// Returns the unit shared by every usable candidate's verified
    /// reward evaluation — the "apples to apples" tier that
    /// ``rewardAdvantageScore`` checks against. `nil` when no two
    /// candidates share a verified unit, which means rewards stop
    /// being a ranker and become context only.
    static func comparableRewardUnit(
        among usables: [PurchaseCandidateAssessment]
    ) -> RewardUnit? {
        let units = usables.compactMap { candidate -> RewardUnit? in
            guard candidate.rewardEvaluation.isUsableForRanking else {
                return nil
            }
            return candidate.rewardEvaluation.unit
        }
        let distinct = Set(units)
        guard distinct.count == 1, let only = distinct.first else {
            return nil
        }
        return only
    }

    /// Severity ordering for the brief sheet. Usable candidates
    /// render first; blocked / excluded rows fall to the bottom.
    static func severityRank(
        _ stance: PurchaseCandidateStance
    ) -> Int {
        switch stance {
        case .usableWithCaveats, .recommended, .fallback: 0
        case .insufficientFunds: 1
        case .insufficientCreditCoverage: 2
        case .snapshotStale: 3
        case .needsSetup: 4
        case .excludedInvestment: 5
        }
    }

    static func severityDescending(
        _ lhs: PurchaseCandidateAssessment,
        _ rhs: PurchaseCandidateAssessment
    ) -> Bool {
        let lhsRank = severityRank(lhs.stance)
        let rhsRank = severityRank(rhs.stance)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        // Severity sort precedes the reward-aware re-rank in
        // `decorate`, so we use a nil comparable unit here and let
        // the decoration pass do the reward-aware ordering.
        return rankingScore(lhs, comparableRewardUnit: nil)
            < rankingScore(rhs, comparableRewardUnit: nil)
    }

    /// Promotes the best usable candidate to `.recommended` and the
    /// next one to `.fallback`. Everything else stays
    /// `.usableWithCaveats` (unless it's already a blocker).
    static func decorate(
        candidates: [PurchaseCandidateAssessment],
        contextIsUsable: Bool
    ) -> [PurchaseCandidateAssessment] {
        guard contextIsUsable else {
            // Without a usable amount the engine refuses to rank.
            return candidates
        }

        let rawUsables = candidates
            .filter { $0.stance == .usableWithCaveats }

        // Figure out whether verified rewards are comparable across
        // the usable set before we rank. If units differ, rewards
        // revert to context-only and the ranking falls back to the
        // pre-rewards tier order.
        let comparableUnit = comparableRewardUnit(among: rawUsables)

        let usables = rawUsables.sorted {
            rankingScore($0, comparableRewardUnit: comparableUnit)
                < rankingScore($1, comparableRewardUnit: comparableUnit)
        }

        guard !usables.isEmpty else {
            return candidates
        }

        var result = candidates
        if let winner = usables.first,
           let idx = result.firstIndex(where: { $0.id == winner.id }) {
            result[idx] = result[idx].with(stance: .recommended)
        }
        if usables.count > 1,
           let idx = result.firstIndex(where: { $0.id == usables[1].id }) {
            result[idx] = result[idx].with(stance: .fallback)
        }
        return result
    }

    // MARK: - Aggregation

    static func topLevelRuling(
        candidates: [PurchaseCandidateAssessment],
        context: PurchaseContext
    ) -> PurchaseDecisionRuling {
        if candidates.isEmpty {
            return .noPaymentAccountsOnFile
        }
        // Treat `excludedInvestment` as "no payment method" for the
        // purpose of the top-level ruling — users with only
        // investment accounts still see that message.
        let paymentMethods = candidates.filter { $0.stance != .excludedInvestment }
        if paymentMethods.isEmpty {
            return .noPaymentAccountsOnFile
        }

        if !context.hasUsableAmount {
            return .needsPurchaseContext
        }

        if candidates.contains(where: { $0.stance == .recommended }) {
            return .ready
        }

        let onlyUsable = paymentMethods.allSatisfy { $0.stance.isUsable }
        let hasMissingData = paymentMethods.contains { candidate in
            candidate.stance == .needsSetup
                || candidate.stance == .snapshotStale
        }

        if !onlyUsable && hasMissingData {
            return .missingCardData
        }
        return .allAccountsBlocked
    }

    static func aggregatedChecks(
        candidates: [PurchaseCandidateAssessment],
        context: PurchaseContext,
        travelContext: PurchaseTravelContext
    ) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for candidate in candidates {
            for check in candidate.outstandingChecks where seen.insert(check).inserted {
                ordered.append(check)
            }
        }
        // Portfolio-level rewards nudge, scoped to rewards-sensitive
        // categories. We show the nudge only when no candidate has a
        // verified + fresh rate on file — once the user records one
        // on any credit card, the engine trusts the per-card narrative
        // above and stops repeating the umbrella check.
        if context.category.isRewardsSensitive {
            let anyVerified = candidates.contains {
                $0.rewardEvaluation.isVerifiedAndFresh
            }
            if !anyVerified {
                let rewardsNote = "Verify any category rewards bonus (\(context.category.displayLabel)) on the issuer's current product page and record it in Settings → Account → Rewards Terms before NomadFi can include rewards in the ranking."
                if seen.insert(rewardsNote).inserted {
                    ordered.append(rewardsNote)
                }
            }
        }

        // Phase 3 follow-through — cross-border / travel checks. Only
        // appended when the travel signal is positive so single-
        // currency purchases stay calm.
        if travelContext.isLikelyCrossBorder {
            for note in crossBorderChecks(travelContext: travelContext)
                where seen.insert(note).inserted {
                ordered.append(note)
            }
        }
        return ordered
    }

    static func warnings(
        for recommendation: PurchaseCandidateAssessment?,
        fallback: PurchaseCandidateAssessment?,
        context: PurchaseContext,
        travelContext: PurchaseTravelContext
    ) -> [String] {
        var warnings: [String] = []
        if let recommendation {
            if recommendation.isCreditCard {
                warnings.append(
                    "Don't rely on this recommendation to carry a balance past the due date — NomadFi never promotes interest-bearing balances."
                )
            }
            if !recommendation.matchesPurchaseCurrency {
                warnings.append(
                    "Purchase currency and account currency differ. Verify the final converted amount before you commit."
                )
            }
        }
        if let fallback, fallback.isCreditCard, recommendation?.isCreditCard == false {
            warnings.append(
                "The fallback is a credit card. Treat it as a pay-in-full path, not a financing path."
            )
        }

        // Phase 3 follow-through — DCC reminder fires when the purchase
        // is likely cross-border. Procedural; never claims that paying
        // in local currency is always cheaper, only that the choice
        // matters and the network conversion terms are the place to
        // verify it.
        if travelContext.isLikelyCrossBorder {
            warnings.append(
                "If the merchant offers a choice between paying in the local currency or your card's currency (Dynamic Currency Conversion), the rate the merchant quotes is set by the merchant — not your network. Confirm the conversion against your network's published terms before agreeing."
            )
        }
        return warnings
    }

    /// Procedural cross-border / DCC / dispute-process reminders.
    /// Each entry maps to a regulator or network publication — the
    /// citation catalog backs the same claims with linked sources.
    static func crossBorderChecks(
        travelContext: PurchaseTravelContext
    ) -> [String] {
        var notes: [String] = []
        notes.append(
            "Verify your card's foreign-currency conversion against the network's published rate or your issuer's current terms before treating the converted amount as final."
        )
        notes.append(
            "If a dispute or refund issue comes up, start with the merchant first. If that does not resolve it, follow your issuer's or bank's published billing-error / dispute process — the procedural steps are not identical across jurisdictions."
        )
        notes.append(
            "Card acceptance and fall-back behaviour can vary by merchant and network. Carry a backup payment method that doesn't rely on the same network or issuer."
        )
        return notes
    }

    // MARK: - Confidence

    /// Result tuple returned by ``derivedConfidence(...)`` — the
    /// label plus the short factual reasons that produced it. Both
    /// are surfaced verbatim in the brief and the dialog layer.
    struct ConfidenceResult: Sendable, Equatable {
        let label: PurchaseDecisionConfidence
        let explanations: [String]
    }

    /// Pure derivation of the recommendation's confidence label.
    /// Rules (highest specificity first):
    ///
    ///   1. No recommendation → `.lowOrUnverified` ("engine could
    ///      not pick").
    ///   2. Recommendation is cross-currency and FX is unverified →
    ///      `.lowOrUnverified`.
    ///   3. Any of: cross-currency with verified FX, travel signal,
    ///      outstanding checks > 0 → `.moderate`.
    ///   4. Otherwise → `.high`.
    static func derivedConfidence(
        recommendation: PurchaseCandidateAssessment?,
        outstandingCheckCount: Int,
        travelContext: PurchaseTravelContext
    ) -> ConfidenceResult {
        guard let recommendation else {
            return ConfidenceResult(
                label: .lowOrUnverified,
                explanations: [
                    "No saved account cleared the engine's guardrails for this purchase, so NomadFi has no recommendation to stand behind.",
                ]
            )
        }

        var notes: [String] = []
        let isCrossCurrency = !recommendation.matchesPurchaseCurrency
        let fxUnverified = isCrossCurrency
            && !recommendation.foreignTransactionFeeIsVerified

        if isCrossCurrency {
            if fxUnverified {
                notes.append(
                    "Recommendation crosses currencies and the foreign-transaction fee on this account is not verified — verify it against the issuer's current terms."
                )
            } else {
                notes.append(
                    "Recommendation crosses currencies; the foreign-transaction fee is verified but the final converted amount still depends on network and merchant timing."
                )
            }
        }
        if travelContext.hasLocationHint {
            notes.append(
                "Location hint is set, so cross-border DCC and dispute-process caveats apply."
            )
        }
        if travelContext.isTravelCategory {
            notes.append(
                "Category is travel — card acceptance and fallback risk are part of the picture."
            )
        }
        if outstandingCheckCount > 0 {
            notes.append(
                "\(outstandingCheckCount) outstanding check\(outstandingCheckCount == 1 ? "" : "s") remain in the brief — clearing them strengthens the next ruling."
            )
        }

        if fxUnverified {
            return ConfidenceResult(label: .lowOrUnverified, explanations: notes)
        }
        if isCrossCurrency
            || travelContext.isLikelyCrossBorder
            || outstandingCheckCount > 0 {
            return ConfidenceResult(label: .moderate, explanations: notes)
        }
        return ConfidenceResult(
            label: .high,
            explanations: [
                "Recommendation matches the purchase currency, no travel signal applies, and no outstanding checks remain — this is the strongest pick the engine produces from saved inputs."
            ]
        )
    }

    // MARK: - Identity

    static func identifier(for account: Account) -> String {
        let institution = account.institutionName.isEmpty
            ? "unknown-issuer"
            : account.institutionName
        let name = account.name.isEmpty ? "unnamed-account" : account.name
        return "purchase-\(institution)-\(name)"
    }

    static func accountDisplayName(for account: Account) -> String {
        let name = account.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let institution = account.institutionName.trimmingCharacters(in: .whitespaces)
        if !institution.isEmpty { return institution }
        return "this account"
    }
}

// MARK: - Assessment mutation helper

private extension PurchaseCandidateAssessment {

    /// Returns a copy with a different stance. Used by the engine's
    /// ranking pass to promote the top two usables to
    /// `.recommended` / `.fallback` without recomputing the rest.
    func with(stance newStance: PurchaseCandidateStance) -> PurchaseCandidateAssessment {
        PurchaseCandidateAssessment(
            id: id,
            accountName: accountName,
            institutionName: institutionName,
            accountTypeDisplay: accountTypeDisplay,
            currencyCode: currencyCode,
            matchesPurchaseCurrency: matchesPurchaseCurrency,
            stance: newStance,
            reasons: reasons,
            outstandingChecks: outstandingChecks,
            currentBalance: currentBalance,
            creditLimit: creditLimit,
            availableCredit: availableCredit,
            isCreditCard: isCreditCard,
            foreignTransactionFeePercent: foreignTransactionFeePercent,
            foreignTransactionFeeIsVerified: foreignTransactionFeeIsVerified,
            rewardEvaluation: rewardEvaluation
        )
    }
}
