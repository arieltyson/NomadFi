// TransactionImportDeduperTests.swift
// NomadFi
//
// Pure-value coverage for the dedupe engine. No SwiftData
// ModelContainer needed — the engine consumes a list of
// `Transaction` values and returns a `DuplicateReason?`.

import Foundation
import Testing

@testable import NomadFi

struct TransactionImportDeduperTests {

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

    private static func parsed(
        merchant: String = "GROCERY STORE",
        amount: Double = -42.50,
        currency: CurrencyCode = .usd,
        date: Date = date(year: 2026, month: 4, day: 20),
        externalID: String? = nil
    ) -> ParsedImportedRow {
        let fingerprint = TransactionImportDeduper.fingerprint(
            normalizedMerchant: merchant,
            amount: amount,
            date: date,
            currency: currency
        )
        return ParsedImportedRow(
            lineNumber: 2,
            rawMerchantName: merchant,
            normalizedMerchantName: merchant,
            inferredCategory: .food,
            amount: amount,
            currencyCode: currency,
            date: date,
            externalTransactionID: externalID,
            fingerprint: fingerprint
        )
    }

    @MainActor
    private static func existing(
        merchant: String = "GROCERY STORE",
        amount: Double = -42.50,
        currency: CurrencyCode = .usd,
        date: Date = date(year: 2026, month: 4, day: 20),
        externalID: String? = nil
    ) -> Transaction {
        let fingerprint = TransactionImportDeduper.fingerprint(
            normalizedMerchant: merchant,
            amount: amount,
            date: date,
            currency: currency
        )
        return Transaction(
            merchantName: merchant,
            originalAmount: amount,
            originalCurrency: currency,
            date: date,
            normalizedMerchantName: merchant,
            importSource: .csvGeneric,
            externalTransactionID: externalID,
            importedAt: date,
            importFingerprint: fingerprint
        )
    }

    // MARK: - External ID match

    @MainActor
    @Test("External transaction ID match is flagged as a duplicate")
    func externalIDMatchIsDuplicate() {
        let row = Self.parsed(externalID: "TXN-1")
        let existing = Self.existing(externalID: "TXN-1")
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing]
        )
        #expect(reason == .externalIDMatch)
    }

    // MARK: - Fingerprint match

    @MainActor
    @Test("Exact fingerprint match with same date is flagged as a duplicate")
    func exactFingerprintSameDateIsDuplicate() {
        let row = Self.parsed()
        let existing = Self.existing()
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing]
        )
        #expect(reason == .fingerprintMatch(dayDelta: 0))
    }

    @MainActor
    @Test("Fingerprint match within the day window is flagged as a duplicate")
    func fingerprintWithinDayWindowIsDuplicate() {
        let row = Self.parsed(
            date: Self.date(year: 2026, month: 4, day: 22)
        )
        let existing = Self.existing(
            date: Self.date(year: 2026, month: 4, day: 20)
        )
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing],
            dayWindow: 3
        )
        #expect(reason == .fingerprintMatch(dayDelta: 2))
    }

    @MainActor
    @Test("Fingerprint match outside the day window is treated as new")
    func fingerprintOutsideWindowIsNew() {
        let row = Self.parsed(
            date: Self.date(year: 2026, month: 5, day: 15)
        )
        let existing = Self.existing(
            date: Self.date(year: 2026, month: 4, day: 20)
        )
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing],
            dayWindow: 3
        )
        #expect(reason == nil)
    }

    // MARK: - Mismatched fields

    @MainActor
    @Test("Different amounts are treated as new rows even with the same merchant and date")
    func differentAmountsAreNew() {
        let row = Self.parsed(amount: -40.00)
        let existing = Self.existing(amount: -42.50)
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing]
        )
        #expect(reason == nil)
    }

    @MainActor
    @Test("Different currencies are treated as new rows")
    func differentCurrenciesAreNew() {
        let row = Self.parsed(currency: .cad)
        let existing = Self.existing(currency: .usd)
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [existing]
        )
        #expect(reason == nil)
    }

    @MainActor
    @Test("Legacy rows without a stored fingerprint still dedupe through on-the-fly synthesis")
    func legacyRowsWithoutFingerprintStillMatch() {
        let row = Self.parsed()
        let legacy = Transaction(
            merchantName: "GROCERY STORE",
            originalAmount: -42.50,
            originalCurrency: .usd,
            date: Self.date(year: 2026, month: 4, day: 20)
            // no normalized merchant, no fingerprint — classic legacy row
        )
        let reason = TransactionImportDeduper.duplicateReason(
            for: row,
            in: [legacy]
        )
        #expect(reason == .fingerprintMatch(dayDelta: 0))
    }
}
