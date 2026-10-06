import Foundation
import Testing
@testable import FiBotEngine

struct FiBotEngineTests {
    private let date = "2026-10-06"
    private let end = "2027-01-04"
    private let coverage = FiBotCoverage(incomeConfirmed: true, obligationsConfirmed: true, accountsComplete: true,
                                        spendingIncluded: true, debtPaymentsIncluded: true)
    private var policy: FiBotPolicy { .init(incomeReductionPercent: 0, expenseIncreasePercent: 0, incomeDelayDays: 0) }
    private func account(_ id: String = "cash", balance: Decimal = 1000, reserve: Decimal = 100, currency: String = "CAD") -> FiBotCashAccount {
        .init(id: id, available: .init(balance, currency: currency), protectedReserve: reserve, observedOn: date, verification: .confirmed)
    }
    private func context(accounts: [FiBotCashAccount]? = nil, flows: [FiBotCashFlow] = [], commitments: [FiBotCommitment] = []) -> FiBotFinancialContext {
        .init(evaluatedOn: date, horizonEnd: end, accounts: accounts ?? [account()], flows: flows, commitments: commitments, coverage: coverage)
    }
    private func purchase(_ amount: Decimal = 100, currency: String = "CAD") -> FiBotPurchase {
        .init(fundingAccountID: "cash", allInCost: .init(amount, currency: currency), costsComplete: true)
    }
    private func expense(_ amount: Decimal, date: String = "2026-10-10", id: String = "bill", account: String = "cash", kind: FiBotFlowKind = .essential) -> FiBotCashFlow {
        .init(id: id, accountID: account, date: date, money: .init(amount, currency: "CAD"), kind: kind)
    }

    @Test func protectsReservesAndFutureBillsWithExactDecimalArithmetic() {
        let decision = FiBotAffordabilityEngine.evaluate(context: context(flows: [expense(Decimal(string: "799.99")!)]),
                                                         purchase: purchase(Decimal(string: "100.01")!), policy: policy)
        #expect(decision.outcome == .affordable)
        #expect(decision.maximumNow?.amount == Decimal(string: "100.01"))
        let blocked = FiBotAffordabilityEngine.evaluate(context: context(flows: [expense(Decimal(string: "799.99")!)]), purchase: purchase(Decimal(string: "100.02")!), policy: policy)
        #expect(blocked.outcome == .wait)
    }

    @Test func missingSalaryOrSpendingCoverageCannotApprove() {
        var input = context()
        input.coverage.incomeConfirmed = false
        input.coverage.spendingIncluded = false
        let decision = FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(), policy: policy)
        #expect(decision.outcome == .needsMoreInformation)
        #expect(decision.maximumNow == nil)
        #expect(decision.reasons.contains("confirm_net_salary_and_pay_dates"))
    }

    @Test func creditLimitAndRestrictedSavingsCannotFundPurchases() {
        var credit = account(balance: 10000); credit.kind = .credit
        var locked = account(); locked.kind = .restricted
        for value in [credit, locked] {
            let result = FiBotAffordabilityEngine.evaluate(context: context(accounts: [value]), purchase: purchase(), policy: policy)
            #expect(result.outcome == .needsMoreInformation)
        }
    }

    @Test func salaryDelayAndExpenseShockCanBlockAnOtherwiseAffordablePurchase() {
        let salary = FiBotCashFlow(id: "pay", accountID: "cash", date: "2026-10-08", money: .init(1000, currency: "CAD"), kind: .netIncome)
        let input = context(accounts: [account(balance: 700)], flows: [salary, expense(500, date: "2026-10-09")])
        #expect(FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(200), policy: policy).outcome == .affordable)
        let stressed = FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(200), policy: .init())
        #expect(stressed.outcome == .wait)
        #expect(stressed.maximumNow?.amount == 50)
    }

    @Test func sameDayBillsAreCheckedBeforeUnsettledSalary() {
        let income = FiBotCashFlow(id: "pay", accountID: "cash", date: date, money: .init(1000, currency: "CAD"), kind: .netIncome)
        let result = FiBotAffordabilityEngine.evaluate(context: context(accounts: [account(balance: 200)], flows: [income, expense(300, date: date)]), purchase: purchase(1), policy: policy)
        #expect(result.outcome == .wait)
    }

    @Test func oneCurrencyCannotSilentlyCoverAnotherAccountsShortfall() {
        let usd = account("usd", balance: 10, reserve: 0, currency: "USD")
        let bill = FiBotCashFlow(id: "usd-bill", accountID: "usd", date: "2026-10-12", money: .init(100, currency: "USD"), kind: .essential)
        let result = FiBotAffordabilityEngine.evaluate(context: context(accounts: [account(balance: 100000), usd], flows: [bill]), purchase: purchase(), policy: policy)
        #expect(result.outcome == .wait)
        #expect(result.reasons.contains("another_account_has_a_shortfall"))
    }

    @Test func commitmentsShareCapacityAndPartialSettlementDoesNotReleaseTheWholeReservation() {
        let commitment = FiBotCommitment(id: "reserved", accountID: "cash", money: .init(500, currency: "CAD"), expiresOn: end)
        var partial = expense(100); partial.commitmentID = commitment.id
        let input = context(flows: [partial], commitments: [commitment])
        let result = FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(401), policy: policy)
        #expect(result.maximumNow?.amount == 400)
        #expect(result.outcome == .wait)
    }

    @Test func optionalGoalsRequireAnExplicitPlanChangeBeforeBuying() {
        let result = FiBotAffordabilityEngine.evaluate(context: context(flows: [expense(800, kind: .optionalGoal)]), purchase: purchase(200), policy: policy)
        #expect(result.outcome == .affordableWithTradeoffs)
        #expect(result.maximumNow?.amount == 100)
        #expect(result.optionalGoalsToReview == ["bill"])
    }

    @Test func unpairedTransfersAndStaleBalancesCannotApprove() {
        var stale = account(); stale.observedOn = "2026-09-01"
        let transfer = FiBotCashFlow(id: "in", accountID: "cash", date: "2026-10-08", money: .init(1000, currency: "CAD"), kind: .transferIn)
        for input in [context(accounts: [stale]), context(flows: [transfer])] {
            #expect(FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(), policy: policy).outcome == .needsMoreInformation)
        }
    }

    @Test func invalidDatesDuplicatesUnknownFeesAndShortHorizonsFailClosed() {
        var dates = context(); dates.horizonEnd = "2026-02-30"
        var short = context(); short.horizonEnd = "2026-10-07"
        var duplicate = context(); duplicate.accounts.append(account())
        for input in [dates, short, duplicate] {
            #expect(FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(), policy: policy).outcome == .needsMoreInformation)
        }
        var unknown = purchase(); unknown.costsComplete = false
        #expect(FiBotAffordabilityEngine.evaluate(context: context(), purchase: unknown, policy: policy).outcome == .needsMoreInformation)
    }

    @Test func moneyJSONUsesDecimalStringsAndRejectsAmbiguousValues() throws {
        let amount = FiBotMoney(Decimal(string: "123456789.12")!, currency: "CAD")
        let data = try JSONEncoder().encode(amount)
        #expect(try JSONDecoder().decode(FiBotMoney.self, from: data) == amount)
        for raw in ["{\"amount\":1.1,\"currency\":\"CAD\"}", "{\"amount\":\"12junk\",\"currency\":\"CAD\"}"] {
            #expect(throws: (any Error).self) { try JSONDecoder().decode(FiBotMoney.self, from: Data(raw.utf8)) }
        }
    }

    @Test func increasingPurchasePriceNeverImprovesTheOutcome() {
        let input = context(flows: [expense(200)])
        var alreadyBlocked = false
        for price in stride(from: 1, through: 1200, by: 17) {
            let result = FiBotAffordabilityEngine.evaluate(context: input, purchase: purchase(Decimal(price)), policy: policy)
            if alreadyBlocked { #expect(result.outcome != .affordable) }
            if result.outcome == .wait { alreadyBlocked = true }
        }
    }
}
