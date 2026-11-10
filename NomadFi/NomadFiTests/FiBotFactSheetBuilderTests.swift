import Foundation
import Testing
@testable import NomadFi

@MainActor
struct FiBotFactSheetBuilderTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func date(_ day: String) -> Date {
        try! Date(day, strategy: Date.ISO8601FormatStyle().year().month().day())
    }

    private func sheet(
        accounts: [Account] = [],
        transactions: [Transaction] = [],
        subscriptions: [Subscription] = [],
        budgets: [Budget] = []
    ) -> FiBotFactSheet {
        FiBotFactSheetBuilder(now: date("2026-11-10"), calendar: calendar).build(
            accounts: accounts,
            transactions: transactions,
            subscriptions: subscriptions,
            budgets: budgets
        )
    }

    private func statement(_ sheet: FiBotFactSheet, topic: String) -> String? {
        sheet.facts.first { $0.topic.hasPrefix(topic) }?.statement
    }

    @Test func anEmptyStoreStillStatesTheDateAndWhatIsMissing() {
        let sheet = sheet()
        #expect(!sheet.hasFinancialData)
        #expect(statement(sheet, topic: "Today") == "2026-11-10")
        #expect(statement(sheet, topic: "What NomadFi can see")?.contains("not included") == true)
    }

    @Test func factsAreNumberedInOrder() {
        let sheet = sheet(accounts: [Account(name: "Everyday", accountType: .checking, currencyCode: .cad, balance: 100)])
        #expect(sheet.facts.map(\.id) == (1...sheet.facts.count).map { "F\($0)" })
    }

    @Test func spendingIsTotalledPerCurrencyAndExcludesIncomeAndTransfers() {
        let transactions = [
            Transaction(merchantName: "Grocer", originalAmount: -100.25, originalCurrency: .cad, date: date("2026-11-03"), category: .food),
            Transaction(merchantName: "Cafe", originalAmount: -20, originalCurrency: .cad, date: date("2026-11-04"), category: .food),
            Transaction(merchantName: "Store", originalAmount: -50, originalCurrency: .usd, date: date("2026-11-05"), category: .shopping),
            Transaction(merchantName: "Employer", originalAmount: 3000, originalCurrency: .cad, date: date("2026-11-01"), category: .income),
            Transaction(merchantName: "Savings", originalAmount: -500, originalCurrency: .cad, date: date("2026-11-02"), category: .transfer),
            Transaction(merchantName: "Old", originalAmount: -75, originalCurrency: .cad, date: date("2026-10-20"), category: .food),
        ]
        let sheet = sheet(transactions: transactions)
        #expect(statement(sheet, topic: "Spending this month (2026-11-01 to 2026-11-10) in CAD") == "CAD 120.25 across 2 transactions")
        #expect(statement(sheet, topic: "Spending this month (2026-11-01 to 2026-11-10) in USD") == "USD 50.00 across 1 transactions")
        #expect(statement(sheet, topic: "Spending last month (2026-10-01 to 2026-10-31) in CAD") == "CAD 75.00 across 1 transactions")
        #expect(statement(sheet, topic: "Income this month") == "CAD 3000.00 across 1 transactions")
        #expect(statement(sheet, topic: "Largest purchase this month") == "Grocer, CAD 100.25 on 2026-11-03")
    }

    @Test func balancesAreNeverConvertedAcrossCurrencies() {
        let sheet = sheet(accounts: [
            Account(name: "Chequing", accountType: .checking, currencyCode: .cad, balance: 1000),
            Account(name: "Savings", accountType: .savings, currencyCode: .cad, balance: 2500.5),
            Account(name: "US Checking", accountType: .checking, currencyCode: .usd, balance: 300),
            Account(name: "Visa", accountType: .creditCard, currencyCode: .cad, currentBalance: 412.3),
        ])
        #expect(statement(sheet, topic: "Cash in checking, savings and wallets, total in CAD") == "CAD 3500.50")
        #expect(statement(sheet, topic: "Cash in checking, savings and wallets, total in USD") == "USD 300.00")
        #expect(statement(sheet, topic: "Owed on credit cards, total in CAD") == "CAD 412.30")
    }

    @Test func subscriptionsAreExpressedAsAMonthlyEquivalent() {
        let sheet = sheet(subscriptions: [
            Subscription(serviceName: "Music", amount: 12, currencyCode: .cad, frequency: .monthly, nextRenewalDate: date("2026-11-20")),
            Subscription(serviceName: "Cloud", amount: 120, currencyCode: .cad, frequency: .annual, nextRenewalDate: date("2027-01-02")),
        ])
        #expect(statement(sheet, topic: "Subscriptions in CAD, monthly equivalent") == "CAD 22.00")
        #expect(statement(sheet, topic: "Subscription Music") == "CAD 12.00 monthly, renews 2026-11-20")
    }
}
