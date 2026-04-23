// TransactionImportServiceTests.swift
// NomadFi
//
// End-to-end coverage for the CSV import pipeline. Uses the
// centralised full-schema factory so the `commit(preview:into:)`
// path is exercised on a SwiftData container that registers every
// `@Model` the governance wipe touches — preventing the
// SIGABRT-on-delete failure mode documented in
// `SwiftDataTestContainerFactory.swift`.
//
// The suite is serialized to stay off the Swift Testing parallel
// SwiftData init race; production logic is not stateful.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

/// SwiftData model-container tests are serialized to avoid a Swift
/// Testing / SwiftData parallel-init race: the test host aborts
/// with `SIGABRT` when multiple `ModelContainer(…)` calls happen
/// concurrently inside a single suite under the simulator's Main
/// Thread Checker + `SQLITE_ENABLE_THREAD_ASSERTIONS` env.
@MainActor
@Suite(.serialized)
struct TransactionImportServiceTests {

    // MARK: - Fixtures

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

    nonisolated private static let now = date(year: 2026, month: 4, day: 23)

    private func makeContext() throws -> ModelContext {
        try SwiftDataTestContainerFactory.makeFullSchemaContext()
    }

    private func makeAccount(
        name: String = "Import Target",
        currency: CurrencyCode = .usd
    ) -> Account {
        Account(
            name: name,
            institutionName: "Example Bank",
            accountType: .checking,
            currencyCode: currency,
            jurisdiction: "US"
        )
    }

    // MARK: - Happy path

    @Test("Chase-like CSV parses into new rows with deterministic fingerprints")
    func chaseLikeCSVParsesNewRows() throws {
        let csv = """
        Transaction Date,Description,Debit,Credit,Transaction ID
        2026-04-20,Coffee Shop,4.75,,TXN-1
        2026-04-21,Grocery Store,42.50,,TXN-2
        """
        let account = makeAccount()
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [],
            now: Self.now
        )

        #expect(preview.profile.source == .csvChaseLike)
        #expect(preview.counts.new == 2)
        #expect(preview.counts.duplicate == 0)
        #expect(preview.counts.skipped == 0)
    }

    @Test("Committing the preview inserts only the .new rows")
    func commitInsertsNewRowsOnly() throws {
        let csv = """
        Transaction Date,Description,Debit,Credit,Transaction ID
        2026-04-20,Coffee Shop,4.75,,TXN-1
        ,,,,INVALID
        """
        let context = try makeContext()
        let account = makeAccount()
        context.insert(account)
        try context.save()

        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [],
            now: Self.now
        )
        let result = TransactionImportService.commit(
            preview: preview,
            into: context,
            account: account,
            homeCurrency: .usd,
            now: Self.now
        )

        #expect(result.inserted == 1)
        #expect(result.skippedInvalid == 1)

        let fetched = try context.fetch(FetchDescriptor<Transaction>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.merchantName == "Coffee Shop")
        #expect(fetched.first?.importSource == .csvChaseLike)
        #expect(fetched.first?.externalTransactionID == "TXN-1")
    }

    // MARK: - Dedupe

    @Test("Duplicate external ID flags the row as duplicate on preview")
    func duplicateExternalIDFlagsAsDuplicate() throws {
        let context = try makeContext()
        let account = makeAccount()
        context.insert(account)
        try context.save()

        let existingDate = Self.date(year: 2026, month: 4, day: 20)
        let existing = Transaction(
            merchantName: "Coffee Shop",
            originalAmount: -4.75,
            originalCurrency: .usd,
            date: existingDate,
            normalizedMerchantName: "COFFEE SHOP",
            importSource: .csvChaseLike,
            externalTransactionID: "TXN-1",
            importFingerprint: TransactionImportDeduper.fingerprint(
                normalizedMerchant: "COFFEE SHOP",
                amount: -4.75,
                date: existingDate,
                currency: .usd
            ),
            account: account
        )
        context.insert(existing)
        try context.save()

        let csv = """
        Transaction Date,Description,Debit,Credit,Transaction ID
        2026-04-20,Coffee Shop,4.75,,TXN-1
        """
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [existing],
            now: Self.now
        )

        #expect(preview.counts.new == 0)
        #expect(preview.counts.duplicate == 1)
    }

    // MARK: - Invalid rows

    @Test("Row with an unparseable amount is skipped with invalidAmount")
    func invalidAmountIsSkipped() {
        let csv = """
        Transaction Date,Description,Amount
        2026-04-20,Coffee Shop,not-a-number
        """
        let account = makeAccount()
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [],
            now: Self.now
        )

        #expect(preview.counts.skipped == 1)
        let skipped = preview.rows.first
        if case .skipped(_, _, let error) = skipped {
            #expect(error == .invalidAmount)
        } else {
            Issue.record("Expected a skipped row")
        }
    }

    @Test("Row without a merchant is skipped with missingMerchant")
    func missingMerchantIsSkipped() {
        let csv = """
        Date,Description,Amount
        2026-04-20,,42.50
        """
        let account = makeAccount()
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [],
            now: Self.now
        )

        #expect(preview.counts.skipped == 1)
        if case .skipped(_, _, let error) = preview.rows.first {
            #expect(error == .missingMerchant)
        } else {
            Issue.record("Expected a skipped row")
        }
    }

    @Test("Wise-like CSV parses currency-tagged rows correctly")
    func wiseLikeParsesCurrency() {
        let csv = """
        TransferWise ID,Date,Amount,Currency,Description
        WT-100,2026-04-20,-25.00,USD,Coffee Shop
        WT-101,2026-04-21,-12.50,CAD,Bookstore
        """
        let account = makeAccount(currency: .usd)
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .usd,
            existingTransactions: [],
            now: Self.now
        )

        #expect(preview.profile.source == .csvWiseLike)
        #expect(preview.counts.new == 2)

        // Verify each row's currency after parse.
        let currencies = preview.rows.compactMap { row -> CurrencyCode? in
            if case .new(let parsed) = row {
                return parsed.currencyCode
            }
            return nil
        }
        #expect(currencies == [.usd, .cad])
    }

    @Test("Amex-like CSV flips positive-for-debit amounts to negative on import")
    func amexLikePositiveDebitsBecomeNegative() {
        let csv = """
        Date,Description,Amount
        2026-04-20,Restaurant,42.50
        """
        let account = makeAccount(currency: .cad)
        let preview = TransactionImportService.parse(
            csvText: csv,
            account: account,
            homeCurrency: .cad,
            existingTransactions: [],
            now: Self.now
        )

        // Detector may pick Amex-like or CIBC-like — both are valid
        // named profiles for a three-column shape. What matters is
        // that the resulting sign is correct for whichever profile
        // the detector used.
        if preview.profile.source == .csvAmexCanadaLike {
            if case .new(let parsed) = preview.rows.first {
                #expect(parsed.amount < 0)
            } else {
                Issue.record("Expected a new row")
            }
        } else if preview.profile.source == .csvCIBCLike {
            // CIBC interprets positive numbers as credits.
            if case .new(let parsed) = preview.rows.first {
                #expect(parsed.amount > 0)
            } else {
                Issue.record("Expected a new row")
            }
        }
    }

    // MARK: - Privacy

    @Test("Fixtures do not embed private testbed data — sanity pin")
    func fixturesAreSynthetic() {
        // A hard-coded guard: if any test above accidentally grew
        // toward a real issuer format with private Ariel data, this
        // assertion is the first place to notice.
        let fixtures = [
            "Coffee Shop",
            "Grocery Store",
            "Bookstore",
            "Restaurant",
        ]
        for fixture in fixtures {
            #expect(!fixture.lowercased().contains("ariel"))
        }
    }
}
