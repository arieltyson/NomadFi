// RecurringChargeDetectorTests.swift
// NomadFi
//
// Pure-value coverage for the generalised recurring-charge
// detector. The detector consumes `[Transaction]` and returns
// `RecurringChargeCandidate` values; it never hits a
// ModelContainer, so these tests can run in parallel.
//
// Fixtures are synthetic — no real issuer data, no private testbed
// merchants.

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct RecurringChargeDetectorTests {

    // MARK: - Helpers

    nonisolated private static func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    nonisolated private static let now = date(year: 2026, month: 5, day: 1)

    private static func makeTransaction(
        merchant: String,
        amount: Double,
        currency: CurrencyCode = .usd,
        category: TransactionCategory = .subscription,
        date: Date,
        normalized: String? = nil
    ) -> Transaction {
        Transaction(
            merchantName: merchant,
            originalAmount: amount,
            originalCurrency: currency,
            date: date,
            category: category,
            normalizedMerchantName: normalized ?? MerchantNormalizer.normalize(merchant)
        )
    }

    // MARK: - Weekly

    @Test("Four weekly charges at the same amount surface as a high-confidence weekly candidate")
    func weeklyPatternDetected() {
        let transactions = [
            Self.makeTransaction(merchant: "Weekly Coffee", amount: -5.50, date: Self.date(year: 2026, month: 4, day: 3)),
            Self.makeTransaction(merchant: "Weekly Coffee", amount: -5.50, date: Self.date(year: 2026, month: 4, day: 10)),
            Self.makeTransaction(merchant: "Weekly Coffee", amount: -5.50, date: Self.date(year: 2026, month: 4, day: 17)),
            Self.makeTransaction(merchant: "Weekly Coffee", amount: -5.50, date: Self.date(year: 2026, month: 4, day: 24)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        #expect(candidates.count == 1)
        let first = candidates.first
        #expect(first?.frequency == .weekly)
        #expect(first?.confidence == .high)
        #expect(first?.matchedTransactionCount == 4)
        #expect(first?.representativeAmount == 5.50)
    }

    // MARK: - Monthly

    @Test("Three monthly charges → high-confidence monthly candidate with next-date projection")
    func monthlyPatternDetected() {
        let transactions = [
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        #expect(candidates.count == 1)
        let first = candidates.first
        #expect(first?.frequency == .monthly)
        #expect(first?.confidence == .high)
        let expectedNext = Calendar(identifier: .gregorian).date(
            byAdding: .month,
            value: 1,
            to: Self.date(year: 2026, month: 4, day: 15)
        )
        #expect(first?.nextEstimatedDate == expectedNext)
    }

    // MARK: - Quarterly / annual

    @Test("Two quarterly charges at a plausible cadence → medium-confidence quarterly")
    func quarterlyPatternDetected() {
        let transactions = [
            Self.makeTransaction(merchant: "Quarterly Cloud", amount: -60, date: Self.date(year: 2026, month: 1, day: 15)),
            Self.makeTransaction(merchant: "Quarterly Cloud", amount: -60, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        #expect(candidates.count == 1)
        #expect(candidates.first?.frequency == .quarterly)
        #expect(candidates.first?.confidence == .medium)
    }

    @Test("Two annual charges → medium-confidence annual")
    func annualPatternDetected() {
        let transactions = [
            Self.makeTransaction(merchant: "Annual License", amount: -120, date: Self.date(year: 2025, month: 4, day: 20)),
            Self.makeTransaction(merchant: "Annual License", amount: -120, date: Self.date(year: 2026, month: 4, day: 18)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        #expect(candidates.count == 1)
        #expect(candidates.first?.frequency == .annual)
    }

    // MARK: - Amount tolerance

    @Test("Amount tolerance allows small FX drift (±5 %) to stay in the same bucket")
    func amountToleranceHonoured() {
        let transactions = [
            Self.makeTransaction(merchant: "FX Service", amount: -50.00, date: Self.date(year: 2026, month: 2, day: 10)),
            Self.makeTransaction(merchant: "FX Service", amount: -51.25, date: Self.date(year: 2026, month: 3, day: 10)),
            Self.makeTransaction(merchant: "FX Service", amount: -49.50, date: Self.date(year: 2026, month: 4, day: 10)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        #expect(candidates.count == 1)
        #expect(candidates.first?.matchedTransactionCount == 3)
        #expect(candidates.first?.frequency == .monthly)
    }

    @Test("Amounts outside the ±5 % window do NOT merge into one candidate")
    func amountsBeyondToleranceDoNotMerge() {
        // Two $30 charges are kept on consecutive months so they
        // satisfy the monthly cadence bucket; the $90 sits in a
        // separate amount bucket and can never join.
        let transactions = [
            Self.makeTransaction(merchant: "Utility Co", amount: -30, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.makeTransaction(merchant: "Utility Co", amount: -90, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.makeTransaction(merchant: "Utility Co", amount: -30, date: Self.date(year: 2026, month: 4, day: 1)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)

        // Only the two $30 charges can pair; the $90 is a lone
        // member and doesn't make a pattern.
        #expect(candidates.count == 1)
        #expect(candidates.first?.representativeAmount == 30)
        #expect(candidates.first?.matchedTransactionCount == 2)
    }

    // MARK: - Merchant normalisation across raw import strings

    @Test("Normalisation clusters variants like 'SQ *COFFEE #1234' and 'Coffee' as one merchant")
    func merchantNormalisationFromImportedStrings() {
        // The raw strings simulate what lands from two different
        // CSV exports of the same merchant.
        let transactions = [
            Self.makeTransaction(
                merchant: "SQ *COFFEE #1234",
                amount: -4.75,
                date: Self.date(year: 2026, month: 3, day: 10),
                normalized: nil
            ),
            Self.makeTransaction(
                merchant: "SQ *COFFEE #1234",
                amount: -4.75,
                date: Self.date(year: 2026, month: 4, day: 10),
                normalized: nil
            ),
            Self.makeTransaction(
                merchant: "COFFEE",
                amount: -4.75,
                date: Self.date(year: 2026, month: 5, day: 10),
                normalized: nil
            ),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)
        #expect(candidates.count == 1)
        #expect(candidates.first?.matchedTransactionCount == 3)
        #expect(candidates.first?.normalizedMerchantKey == "COFFEE")
    }

    // MARK: - Rejection of non-recurring input

    @Test("A single transaction never produces a candidate")
    func singleTransactionHasNoCandidate() {
        let transactions = [
            Self.makeTransaction(merchant: "One Off", amount: -42, date: Self.date(year: 2026, month: 4, day: 1)),
        ]
        #expect(RecurringChargeDetector.detect(from: transactions, now: Self.now).isEmpty)
    }

    @Test("Two transactions spaced weirdly (45 days) fall outside every cadence bucket")
    func irregularIntervalIsDropped() {
        let transactions = [
            Self.makeTransaction(merchant: "Random", amount: -10, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.makeTransaction(merchant: "Random", amount: -10, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        #expect(RecurringChargeDetector.detect(from: transactions, now: Self.now).isEmpty)
    }

    // MARK: - Currency & merchant separation

    @Test("The same merchant in two currencies does not collapse into one candidate")
    func differentCurrenciesStaySeparate() {
        let transactions = [
            Self.makeTransaction(merchant: "Streaming Plus", amount: -10, currency: .usd, date: Self.date(year: 2026, month: 3, day: 5)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -10, currency: .usd, date: Self.date(year: 2026, month: 4, day: 5)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -12, currency: .cad, date: Self.date(year: 2026, month: 3, day: 5)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -12, currency: .cad, date: Self.date(year: 2026, month: 4, day: 5)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)
        #expect(candidates.count == 2)
        let currencies = Set(candidates.map(\.currencyCode))
        #expect(currencies == Set([.usd, .cad]))
    }

    @Test("Different merchants never merge, even at the same cadence and amount")
    func differentMerchantsStaySeparate() {
        let transactions = [
            Self.makeTransaction(merchant: "Merchant A", amount: -10, date: Self.date(year: 2026, month: 3, day: 10)),
            Self.makeTransaction(merchant: "Merchant A", amount: -10, date: Self.date(year: 2026, month: 4, day: 10)),
            Self.makeTransaction(merchant: "Merchant B", amount: -10, date: Self.date(year: 2026, month: 3, day: 10)),
            Self.makeTransaction(merchant: "Merchant B", amount: -10, date: Self.date(year: 2026, month: 4, day: 10)),
        ]
        let candidates = RecurringChargeDetector.detect(from: transactions, now: Self.now)
        #expect(candidates.count == 2)
    }

    // MARK: - Income & transfers excluded

    @Test("Income rows are excluded — paycheques are not 'recurring charges'")
    func incomeIsExcluded() {
        let transactions = [
            Self.makeTransaction(merchant: "Payroll", amount: 2000, category: .income, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.makeTransaction(merchant: "Payroll", amount: 2000, category: .income, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        #expect(RecurringChargeDetector.detect(from: transactions, now: Self.now).isEmpty)
    }

    @Test("Transfers between own accounts are excluded")
    func transfersAreExcluded() {
        let transactions = [
            Self.makeTransaction(merchant: "Internal Transfer", amount: -500, category: .transfer, date: Self.date(year: 2026, month: 3, day: 1)),
            Self.makeTransaction(merchant: "Internal Transfer", amount: -500, category: .transfer, date: Self.date(year: 2026, month: 4, day: 1)),
        ]
        #expect(RecurringChargeDetector.detect(from: transactions, now: Self.now).isEmpty)
    }

    // MARK: - Subscription regression

    @Test("SubscriptionDetector still returns the same detections after delegating to the generic detector")
    func subscriptionDetectorMapsRecurringOutput() {
        let transactions = [
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 2, day: 15)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 3, day: 15)),
            Self.makeTransaction(merchant: "Streaming Plus", amount: -15.99, date: Self.date(year: 2026, month: 4, day: 15)),
        ]
        let detected = SubscriptionDetector.detect(from: transactions)

        #expect(detected.count == 1)
        let first = detected.first
        #expect(first?.merchantName == "Streaming Plus")
        #expect(first?.amount == 15.99)
        #expect(first?.frequency == .monthly)
        #expect(first?.confidence == .high)
        #expect(first?.matchedTransactionCount == 3)
    }
}
