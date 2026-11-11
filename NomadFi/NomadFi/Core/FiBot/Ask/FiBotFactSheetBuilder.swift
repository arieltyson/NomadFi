// FiBotFactSheetBuilder.swift
// NomadFi
//
// Turns the user's SwiftData records into Ask FiBot's numbered facts.

import Foundation

/// Builds the fact sheet Ask FiBot answers from.
///
/// Every number is computed here, deterministically, so the language
/// model never does arithmetic on raw records: it only phrases facts
/// this builder already established. The sheet is compact because the
/// on-device model has a small context window, and amounts are written
/// as `CAD 1240.50` so ``FiBotFigureVerifier`` can read them back.
///
/// Totals are kept per currency. NomadFi never converts between
/// currencies here, because a converted total would be a figure the
/// user's banks never reported.
@MainActor
struct FiBotFactSheetBuilder {

    /// The most accounts listed one by one.
    static let accountLimit = 15
    /// The most subscriptions listed one by one.
    static let subscriptionLimit = 10
    /// The most budgets listed.
    static let budgetLimit = 8
    /// Categories and merchants listed per currency.
    static let rankingLimit = 3

    /// Merchants listed inside each top category.
    static let merchantsPerCategory = 4

    let now: Date
    let calendar: Calendar

    init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    /// Builds the sheet from the user's records.
    func build(
        accounts: [Account],
        transactions: [Transaction],
        subscriptions: [Subscription],
        budgets: [Budget]
    ) -> FiBotFactSheet {
        var entries: [(topic: String, statement: String)] = []
        entries.append(("Today", day(now)))
        entries.append(coverage(accounts: accounts, transactions: transactions))
        entries += accountFacts(accounts)
        entries += balanceTotals(accounts)
        entries += spendingFacts(transactions)
        entries += subscriptionFacts(subscriptions)
        entries += budgetFacts(budgets)

        let facts = entries.enumerated().map { index, entry in
            FiBotFact(id: "F\(index + 1)", topic: entry.topic, statement: entry.statement)
        }
        return FiBotFactSheet(
            facts: facts,
            hasFinancialData: !accounts.isEmpty || !transactions.isEmpty
        )
    }

    // MARK: - Coverage

    private func coverage(accounts: [Account], transactions: [Transaction]) -> (String, String) {
        let dates = transactions.map(\.date)
        let range = if let first = dates.min(), let last = dates.max() {
            ", dated \(day(first)) to \(day(last))"
        } else {
            ""
        }
        return (
            "What NomadFi can see",
            "\(accounts.count) accounts and \(transactions.count) transactions\(range). Accounts and spending not added to NomadFi are not included."
        )
    }

    // MARK: - Accounts

    private func accountFacts(_ accounts: [Account]) -> [(String, String)] {
        accounts
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(Self.accountLimit)
            .map { account in
                let code = account.currencyCodeRawValue
                let type = account.accountType?.displayName ?? "Account"
                var parts: [String] = []
                if account.isCreditCard {
                    parts.append(account.currentBalance.map { "owed \(money($0, code))" } ?? "balance not entered")
                    if let limit = account.creditLimit { parts.append("credit limit \(money(limit, code))") }
                    if let due = account.paymentDueDate { parts.append("payment due \(day(due))") }
                } else {
                    parts.append(account.latestBalanceForDisplay.map { "balance \(money($0, code))" } ?? "balance not entered")
                }
                parts.append("updated \(day(account.financialSnapshotUpdatedAt ?? account.lastUpdatedAt))")
                let institution = account.institutionName.isEmpty ? "" : " at \(account.institutionName)"
                return ("Account \(name(account.name))\(name(institution)) (\(type), \(code))", parts.joined(separator: "; "))
            }
    }

    private func balanceTotals(_ accounts: [Account]) -> [(String, String)] {
        let groups: [(String, (Account) -> Bool, (Account) -> Double?)] = [
            ("Cash in checking, savings and wallets", { $0.accountType.map { [.checking, .savings, .wallet].contains($0) } ?? false }, \.latestBalanceForDisplay),
            ("Investments", { $0.accountType == .investment }, \.latestBalanceForDisplay),
            ("Owed on credit cards", \.isCreditCard, \.currentBalance),
        ]
        return groups.flatMap { label, isIncluded, amount in
            totals(accounts.filter(isIncluded).compactMap { account in
                amount(account).map { (account.currencyCodeRawValue, $0) }
            })
            .map { code, total in ("\(label), total in \(code)", money(total, code)) }
        }
    }

    // MARK: - Spending and income

    private func spendingFacts(_ transactions: [Transaction]) -> [(String, String)] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now),
              let lastMonthDay = calendar.date(byAdding: .day, value: -1, to: thisMonth.start),
              let lastMonth = calendar.dateInterval(of: .month, for: lastMonthDay) else { return [] }

        let monthToDate = transactions.filter { $0.date >= thisMonth.start && $0.date <= now }
        let previous = transactions.filter { lastMonth.contains($0.date) && $0.date < lastMonth.end }
        let thisLabel = "this month (\(day(thisMonth.start)) to \(day(now)))"
        let lastLabel = "last month (\(day(lastMonth.start)) to \(day(lastMonthDay)))"

        var facts: [(String, String)] = []
        facts += flowTotals("Spending \(thisLabel)", monthToDate.filter(isSpending))
        facts += flowTotals("Spending \(lastLabel)", previous.filter(isSpending))
        facts += flowTotals("Income \(thisLabel)", monthToDate.filter(isIncome))
        facts += flowTotals("Income \(lastLabel)", previous.filter(isIncome))
        facts += rankings("Top spending categories this month", monthToDate.filter(isSpending)) {
            ($0.category ?? .other).displayName
        }
        facts += rankings("Top merchants this month", monthToDate.filter(isSpending), key: merchant)
        facts += categoryBreakdowns(monthToDate.filter(isSpending))
        if let largest = monthToDate.filter(isSpending).max(by: { abs($0.originalAmount) < abs($1.originalAmount) }) {
            facts.append((
                "Largest purchase this month",
                "\(name(largest.merchantName)), \(money(abs(largest.originalAmount), largest.originalCurrencyRawValue)) on \(day(largest.date))"
            ))
        }
        return facts
    }

    private func flowTotals(_ label: String, _ transactions: [Transaction]) -> [(String, String)] {
        let byCurrency = Dictionary(grouping: transactions, by: \.originalCurrencyRawValue)
        return byCurrency.keys.sorted().compactMap { code in
            guard let rows = byCurrency[code] else { return nil }
            let total = rows.reduce(0) { $0 + abs($1.originalAmount) }
            return ("\(label) in \(code)", "\(money(total, code)) across \(rows.count) transactions")
        }
    }

    private func rankings(
        _ label: String,
        _ transactions: [Transaction],
        key: (Transaction) -> String
    ) -> [(String, String)] {
        let byCurrency = Dictionary(grouping: transactions, by: \.originalCurrencyRawValue)
        return byCurrency.keys.sorted().compactMap { code in
            guard let rows = byCurrency[code] else { return nil }
            let ranked = Dictionary(grouping: rows, by: key)
                .mapValues { $0.reduce(0) { $0 + abs($1.originalAmount) } }
                .sorted { $0.value > $1.value }
                .prefix(Self.rankingLimit)
                .map { "\($0.key) \(money($0.value, code))" }
            guard !ranked.isEmpty else { return nil }
            return ("\(label) in \(code)", ranked.joined(separator: "; "))
        }
    }

    /// For each top category, the merchants the money went to, so FiBot
    /// can say what a category's total was actually spent on.
    private func categoryBreakdowns(_ transactions: [Transaction]) -> [(String, String)] {
        let byCurrency = Dictionary(grouping: transactions, by: \.originalCurrencyRawValue)
        return byCurrency.keys.sorted().flatMap { code -> [(String, String)] in
            Dictionary(grouping: byCurrency[code] ?? []) { ($0.category ?? .other).displayName }
                .map { (category: $0.key, rows: $0.value, total: $0.value.reduce(0) { $0 + abs($1.originalAmount) }) }
                .sorted { $0.total > $1.total }
                .prefix(Self.rankingLimit)
                .map { group in
                    let merchants = Dictionary(grouping: group.rows, by: merchant)
                        .mapValues { $0.reduce(0) { $0 + abs($1.originalAmount) } }
                        .sorted { $0.value > $1.value }
                    var parts = merchants.prefix(Self.merchantsPerCategory).map { "\($0.key) \(money($0.value, code))" }
                    let unlisted = merchants.count - parts.count
                    if unlisted > 0 { parts.append("and \(unlisted) more") }
                    return ("\(group.category) purchases this month in \(code), by merchant", parts.joined(separator: "; "))
                }
        }
    }

    /// The merchant a transaction is grouped and shown under.
    private func merchant(_ transaction: Transaction) -> String {
        name(transaction.normalizedMerchantName ?? transaction.merchantName)
    }

    /// Mirrors ``SpendingTrendComputer``: anything that is not income
    /// or a transfer is spending, whatever its sign.
    private func isSpending(_ transaction: Transaction) -> Bool {
        let category = transaction.category ?? .other
        return category != .income && category != .transfer && transaction.originalAmount != 0
    }

    private func isIncome(_ transaction: Transaction) -> Bool {
        transaction.category == .income && transaction.originalAmount != 0
    }

    // MARK: - Subscriptions and budgets

    private func subscriptionFacts(_ subscriptions: [Subscription]) -> [(String, String)] {
        guard !subscriptions.isEmpty else { return [] }
        let monthly = subscriptions.map { subscription in
            let multiplier = subscription.frequency?.annualizedMultiplier ?? BillingFrequency.monthly.annualizedMultiplier
            return (subscription.currencyCodeRawValue, subscription.amount * multiplier / 12)
        }
        var facts = totals(monthly).map { code, total in
            ("Subscriptions in \(code), monthly equivalent", money(total, code))
        }
        facts += subscriptions
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }
            .prefix(Self.subscriptionLimit)
            .map { subscription in
                let frequency = subscription.frequency?.displayName.lowercased() ?? "monthly"
                return (
                    "Subscription \(name(subscription.serviceName))",
                    "\(money(subscription.amount, subscription.currencyCodeRawValue)) \(frequency), renews \(day(subscription.nextRenewalDate))"
                )
            }
        return facts
    }

    private func budgetFacts(_ budgets: [Budget]) -> [(String, String)] {
        budgets.prefix(Self.budgetLimit).map { budget in
            let code = budget.currencyCodeRawValue
            let period = budget.period?.rawValue ?? "monthly"
            return (
                "Budget \(name(budget.name)) (\(period))",
                "spent \(money(budget.spentAmount, code)) of \(money(budget.limitAmount, code)); \(money(budget.remainingAmount, code)) left"
            )
        }
    }

    // MARK: - Formatting

    /// A name written by a bank, merchant or the person, with any long
    /// identifying number masked before the model sees it.
    private func name(_ text: String) -> String {
        SensitiveNumberRedactor.redactingName(text)
    }

    /// Sums amounts per currency code, sorted by code.
    private func totals(_ amounts: [(String, Double)]) -> [(String, Double)] {
        Dictionary(amounts, uniquingKeysWith: +).sorted { $0.key < $1.key }
    }

    /// `CAD 1240.50`: no grouping and a fixed decimal point, so the
    /// verifier reads it back the same in every locale.
    private func money(_ amount: Double, _ code: String) -> String {
        let number = amount.formatted(
            .number
                .precision(.fractionLength(2))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        return "\(code) \(number)"
    }

    /// `2026-11-10`, in the calendar's time zone.
    private func day(_ date: Date) -> String {
        date.formatted(
            Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        )
    }
}
