import Foundation

public enum FiBotOutcome: String, Codable, Sendable {
    case affordable, affordableWithTradeoffs, wait, needsMoreInformation
}
public struct FiBotForecastPoint: Codable, Sendable {
    public let accountID: String
    public let date: String
    public let remainingAfterReserve: FiBotMoney
}
public struct FiBotDecision: Codable, Sendable {
    public let outcome: FiBotOutcome
    public let maximumNow: FiBotMoney?
    public let reasons: [String]
    public let baseline: [FiBotForecastPoint]
    public let stress: [FiBotForecastPoint]
    public let policyVersion: String
    public let evidenceIDs: [String]
    public let optionalGoalsToReview: [String]
}

public enum FiBotAffordabilityEngine {
    public static func evaluate(context: FiBotFinancialContext, purchase: FiBotPurchase, policy: FiBotPolicy = .init()) -> FiBotDecision {
        let missing = validate(context, purchase, policy)
        guard missing.isEmpty else { return decision(.needsMoreInformation, reasons: missing, policy: policy) }
        let base = forecast(context, purchase, policy, stressed: false, deferGoals: false)
        let stress = forecast(context, purchase, policy, stressed: true, deferGoals: false)
        let capacity = centsDown(max(0, min(base.capacity, stress.capacity)))
        let fits = !base.otherAccountShortfall && !stress.otherAccountShortfall && purchase.allInCost.amount <= capacity
            && base.capacity >= 0 && stress.capacity >= 0
        if fits {
            return decision(.affordable, maximum: .init(capacity, currency: purchase.allInCost.currency),
                            reasons: ["covers_confirmed_plan_and_stress"], base: base.points, stress: stress.points, policy: policy)
        }
        let optional = context.flows.filter { $0.kind == .optionalGoal }.map(\.id)
        if !optional.isEmpty {
            let relaxedBase = forecast(context, purchase, policy, stressed: false, deferGoals: true)
            let relaxedStress = forecast(context, purchase, policy, stressed: true, deferGoals: true)
            if !relaxedBase.otherAccountShortfall && !relaxedStress.otherAccountShortfall
                && purchase.allInCost.amount <= min(relaxedBase.capacity, relaxedStress.capacity) {
                return decision(.affordableWithTradeoffs, maximum: .init(capacity, currency: purchase.allInCost.currency),
                                reasons: ["confirm_optional_goal_changes_before_buying"], base: base.points,
                                stress: stress.points, policy: policy, optionalGoals: optional)
            }
        }
        return decision(.wait, maximum: .init(capacity, currency: purchase.allInCost.currency),
                        reasons: [base.otherAccountShortfall || stress.otherAccountShortfall ? "another_account_has_a_shortfall" : "purchase_reduces_protected_cash"],
                        base: base.points, stress: stress.points, policy: policy)
    }

    private static func validate(_ context: FiBotFinancialContext, _ purchase: FiBotPurchase, _ policy: FiBotPolicy) -> [String] {
        var reasons: [String] = []
        guard let today = day(context.evaluatedOn), let end = day(context.horizonEnd), end >= today,
              end.timeIntervalSince(today) >= 90 * 86400,
              end.timeIntervalSince(today) <= 366 * 86400 else { return ["confirm_90_day_or_longer_forecast"] }
        if !context.coverage.incomeConfirmed { reasons.append("confirm_net_salary_and_pay_dates") }
        if !context.coverage.obligationsConfirmed { reasons.append("confirm_bills_and_irregular_costs") }
        if !context.coverage.accountsComplete { reasons.append("confirm_all_accounts_and_shared_funds") }
        if !context.coverage.spendingIncluded { reasons.append("include_expected_variable_spending") }
        if !context.coverage.debtPaymentsIncluded { reasons.append("confirm_debt_payment_schedules") }
        if !purchase.costsComplete { reasons.append("confirm_tax_fees_and_ownership_costs") }
        if policy.version != "cash-flow-v1" { reasons.append("unsupported_policy_version") }
        guard context.accounts.count <= 100, context.flows.count + purchase.ownershipCosts.count <= 10000,
              context.commitments.count <= 1000 else { return ["context_limit_exceeded"] }
        guard policy.maximumBalanceAgeDays >= 0, policy.maximumBalanceAgeDays <= 30,
              validPercent(policy.incomeReductionPercent), validPercent(policy.expenseIncreasePercent),
              (0...30).contains(policy.incomeDelayDays) else { return ["invalid_scenario_policy"] }
        let accounts = context.accounts.filter { $0.kind == .cash }
        if Set(context.accounts.map(\.id)).count != context.accounts.count { reasons.append("duplicate_account_identity") }
        guard let funding = accounts.first(where: { $0.id == purchase.fundingAccountID }) else { return reasons + ["select_accessible_cash_account"] }
        if !valid(purchase.allInCost) || purchase.allInCost.amount <= 0 || purchase.allInCost.currency != funding.available.currency {
            reasons.append("confirm_purchase_currency_and_all_in_amount")
        }
        for account in accounts {
            if !["CAD", "USD"].contains(account.available.currency) { reasons.append("unsupported_currency") }
            if account.id.isEmpty || !valid(account.available) || account.available.amount < 0
                || account.protectedReserve.isNaN || account.protectedReserve < 0 || account.protectedReserve > 1_000_000_000_000 {
                reasons.append("invalid_cash_or_reserve")
            }
            guard let observed = day(account.observedOn), observed <= today,
                  today.timeIntervalSince(observed) <= Double(policy.maximumBalanceAgeDays) * 86400,
                  [.observed, .confirmed].contains(account.verification) else {
                reasons.append("confirm_fresh_accessible_balances"); continue
            }
        }
        let flows = context.flows + purchase.ownershipCosts
        if Set(flows.map(\.id)).count != flows.count { reasons.append("duplicate_cash_flow_identity") }
        for flow in flows {
            guard let account = accounts.first(where: { $0.id == flow.accountID }), valid(flow.money), flow.money.amount >= 0,
                  flow.money.currency == account.available.currency, let date = day(flow.date), date >= today, date <= end,
                  flow.verification == .confirmed else {
                reasons.append("confirm_dated_cash_flows_and_extend_horizon_if_needed"); continue
            }
            if flow.kind == .transferIn || flow.kind == .transferOut {
                let pair = flows.filter { $0.transferID == flow.transferID && flow.transferID != nil }
                guard pair.count == 2, let incoming = pair.first(where: { $0.kind == .transferIn }),
                      let outgoing = pair.first(where: { $0.kind == .transferOut }), incoming.accountID != outgoing.accountID,
                      incoming.date >= outgoing.date else { reasons.append("reconcile_transfer_and_settlement"); continue }
                if incoming.money.currency == outgoing.money.currency && incoming.money.amount > outgoing.money.amount {
                    reasons.append("transfer_cannot_create_money")
                }
                if incoming.money.currency != outgoing.money.currency {
                    reasons.append("cross_currency_transfer_requires_reviewed_settlement_quote")
                }
            }
        }
        if purchase.ownershipCosts.contains(where: { $0.kind.isInflow || $0.kind == .optionalGoal }) { reasons.append("ownership_costs_must_be_outflows") }
        if Set(context.commitments.map(\.id)).count != context.commitments.count { reasons.append("duplicate_commitment_identity") }
        for commitment in context.commitments {
            guard let account = accounts.first(where: { $0.id == commitment.accountID }), valid(commitment.money),
                  commitment.money.amount > 0, commitment.money.currency == account.available.currency, day(commitment.expiresOn) != nil else {
                reasons.append("reconcile_purchase_commitments"); continue
            }
        }
        for flow in flows where flow.commitmentID != nil {
            guard let commitment = context.commitments.first(where: { $0.id == flow.commitmentID }),
                  commitment.accountID == flow.accountID, commitment.money.currency == flow.money.currency,
                  !flow.kind.isInflow else { reasons.append("reconcile_purchase_commitments"); continue }
        }
        return Array(Set(reasons)).sorted()
    }

    private struct Forecast {
        var capacity: Decimal
        var otherAccountShortfall: Bool
        var points: [FiBotForecastPoint]
    }
    private static func forecast(_ context: FiBotFinancialContext, _ purchase: FiBotPurchase, _ policy: FiBotPolicy,
                                 stressed: Bool, deferGoals: Bool) -> Forecast {
        let accounts = context.accounts.filter { $0.kind == .cash }
        var balances = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.available.amount - $0.protectedReserve) })
        let flows = (context.flows + purchase.ownershipCosts).filter { !deferGoals || $0.kind != .optionalGoal }
        for commitment in context.commitments where commitment.expiresOn >= context.evaluatedOn {
            let scheduled = flows.filter { $0.commitmentID == commitment.id }.reduce(Decimal.zero) { $0 + $1.money.amount }
            balances[commitment.accountID, default: 0] -= max(0, commitment.money.amount - scheduled)
        }
        var adjusted = flows.map { flow -> FiBotCashFlow in
            var result = flow
            if stressed && flow.kind == .netIncome {
                result.money = .init(flow.money.amount * (100 - policy.incomeReductionPercent) / 100, currency: flow.money.currency)
                result.date = shifted(flow.date, by: policy.incomeDelayDays)
            } else if stressed && [.essential, .discretionary].contains(flow.kind) {
                result.money = .init(flow.money.amount * (100 + policy.expenseIncreasePercent) / 100, currency: flow.money.currency)
            }
            return result
        }.filter { $0.date <= context.horizonEnd }
        adjusted.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.kind.isInflow != $1.kind.isInflow { return !$0.kind.isInflow }
            return $0.id < $1.id
        }
        var capacity = balances[purchase.fundingAccountID] ?? 0
        var shortfall = accounts.contains { $0.id != purchase.fundingAccountID && balances[$0.id, default: 0] < 0 }
        var points = accounts.map { FiBotForecastPoint(accountID: $0.id, date: context.evaluatedOn,
            remainingAfterReserve: .init(balances[$0.id, default: 0] - ($0.id == purchase.fundingAccountID ? purchase.allInCost.amount : 0), currency: $0.available.currency)) }
        for flow in adjusted {
            balances[flow.accountID, default: 0] += flow.kind.isInflow ? flow.money.amount : -flow.money.amount
            let current = balances[flow.accountID, default: 0]
            if flow.accountID == purchase.fundingAccountID { capacity = min(capacity, current) }
            else if current < 0 { shortfall = true }
            points.append(.init(accountID: flow.accountID, date: flow.date,
                                remainingAfterReserve: .init(current - (flow.accountID == purchase.fundingAccountID ? purchase.allInCost.amount : 0), currency: flow.money.currency)))
        }
        return .init(capacity: capacity, otherAccountShortfall: shortfall, points: points)
    }

    private static func decision(_ outcome: FiBotOutcome, maximum: FiBotMoney? = nil, reasons: [String],
                                 base: [FiBotForecastPoint] = [], stress: [FiBotForecastPoint] = [],
                                 policy: FiBotPolicy, optionalGoals: [String] = []) -> FiBotDecision {
        .init(outcome: outcome, maximumNow: maximum, reasons: reasons, baseline: base, stress: stress,
              policyVersion: policy.version, evidenceIDs: ["R3", "R4", "R5"], optionalGoalsToReview: optionalGoals)
    }
    private static func valid(_ value: FiBotMoney) -> Bool {
        !value.amount.isNaN && abs(value.amount) <= 1_000_000_000_000
            && value.currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil
    }
    private static func validPercent(_ value: Decimal) -> Bool { !value.isNaN && value >= 0 && value <= 100 }
    private static func centsDown(_ value: Decimal) -> Decimal {
        var input = value, output = Decimal.zero
        NSDecimalRound(&output, &input, 2, .down)
        return output
    }
    private static func day(_ value: String) -> Date? {
        guard value.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
    private static func shifted(_ value: String, by days: Int) -> String {
        guard let date = day(value) else { return value }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date.addingTimeInterval(Double(days) * 86400))
    }
}
