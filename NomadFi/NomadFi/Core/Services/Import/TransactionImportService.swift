// TransactionImportService.swift
// NomadFi
//
// End-to-end orchestrator for CSV transaction imports. The service
// is split into two pure entry points so the UI can show a preview
// before any writes happen:
//
//   - `parse(csvText:...)` → `TransactionImportPreview`
//       No SwiftData writes. Every row becomes a
//       `TransactionImportPreviewRow` whose kind (`new`, `duplicate`,
//       `skipped`) tells the UI what to do.
//
//   - `commit(preview:into:)` → `TransactionImportCommitResult`
//       Inserts only `.new` rows as `Transaction`s on the chosen
//       account. Never re-evaluates dedupe; that already happened
//       at preview time. Rows the user explicitly dropped are
//       skipped by filtering the preview's `rows` before passing
//       in, which the UI handles.
//
// Deterministic by design: no network, no AI, no locale-specific
// currency sniffing. Every rule is declarative and testable.

import Foundation
import OSLog
import SwiftData

/// High-level entry point for CSV transaction imports. Stateless
/// namespace — each call produces a fresh value from its inputs.
enum TransactionImportService {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "TransactionImport"
    )

    // MARK: - Public API

    /// Parses CSV text into a preview the UI can render before any
    /// writes happen.
    @MainActor
    static func parse(
        csvText: String,
        profileOverride: CSVImportProfile? = nil,
        account: Account,
        homeCurrency: CurrencyCode,
        existingTransactions: [Transaction],
        now: Date = .now
    ) -> TransactionImportPreview {
        let rows = CSVRowParser.rows(
            from: csvText,
            delimiter: profileOverride?.delimiter ?? .comma
        )

        guard !rows.isEmpty, let headerRow = rows.first else {
            return TransactionImportPreview(
                profile: profileOverride ?? TransactionImportProfile.generic,
                rows: [],
                counts: .zero
            )
        }

        let profile = profileOverride
            ?? TransactionImportProfile.detect(from: headerRow)

        let columns = ColumnMap(headers: headerRow, profile: profile)

        // If the header row itself is missing required columns,
        // every downstream row is implicitly a skipped-header-error.
        // The UI surfaces one row per source line so the user still
        // sees what happened.
        guard columns.isUsable else {
            let skipped = rows.dropFirst().enumerated().map { (offset, row) -> TransactionImportPreviewRow in
                .skipped(
                    lineNumber: offset + 2,
                    raw: row.joined(separator: String(profile.delimiter.character)),
                    error: .profileColumnMissing
                )
            }
            return TransactionImportPreview(
                profile: profile,
                rows: Array(skipped),
                counts: TransactionImportCounts(
                    new: 0,
                    duplicate: 0,
                    skipped: skipped.count
                )
            )
        }

        let sameAccountTransactions = existingTransactions
            .filter { $0.account?.persistentModelID == account.persistentModelID }

        var previewRows: [TransactionImportPreviewRow] = []
        var newCount = 0
        var duplicateCount = 0
        var skippedCount = 0

        for (offset, row) in rows.dropFirst().enumerated() {
            let lineNumber = offset + 2

            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                skippedCount += 1
                previewRows.append(.skipped(
                    lineNumber: lineNumber,
                    raw: "",
                    error: .emptyRow
                ))
                continue
            }

            switch parseRow(
                row,
                lineNumber: lineNumber,
                columns: columns,
                profile: profile
            ) {
            case .failure(let error):
                skippedCount += 1
                previewRows.append(.skipped(
                    lineNumber: lineNumber,
                    raw: row.joined(separator: String(profile.delimiter.character)),
                    error: error
                ))
            case .success(let parsed):
                let duplicateReason = TransactionImportDeduper.duplicateReason(
                    for: parsed,
                    in: sameAccountTransactions
                )
                if let reason = duplicateReason {
                    duplicateCount += 1
                    previewRows.append(.duplicate(
                        parsed,
                        reason: reason.displayLabel
                    ))
                } else {
                    newCount += 1
                    previewRows.append(.new(parsed))
                }
            }
        }

        return TransactionImportPreview(
            profile: profile,
            rows: previewRows,
            counts: TransactionImportCounts(
                new: newCount,
                duplicate: duplicateCount,
                skipped: skippedCount
            )
        )
    }

    /// Commits the `.new` rows from `preview` into `modelContext`
    /// as `Transaction` records attached to `account`.
    @MainActor
    @discardableResult
    static func commit(
        preview: TransactionImportPreview,
        into modelContext: ModelContext,
        account: Account,
        homeCurrency: CurrencyCode,
        now: Date = .now
    ) -> TransactionImportCommitResult {
        var inserted = 0
        var skippedDuplicates = 0
        var skippedInvalid = 0

        for row in preview.rows {
            switch row {
            case .new(let parsed):
                let transaction = makeTransaction(
                    from: parsed,
                    account: account,
                    homeCurrency: homeCurrency,
                    source: preview.profile.source,
                    now: now
                )
                modelContext.insert(transaction)
                inserted += 1
            case .duplicate:
                skippedDuplicates += 1
            case .skipped:
                skippedInvalid += 1
            }
        }

        if inserted > 0 {
            do {
                try modelContext.save()
            } catch {
                logger.error(
                    "Failed to save imported transactions: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return TransactionImportCommitResult(
            inserted: inserted,
            skippedDuplicates: skippedDuplicates,
            skippedInvalid: skippedInvalid
        )
    }

    // MARK: - Row parsing

    private struct ColumnMap {
        let dateIndex: Int?
        let merchantIndex: Int?
        let amountIndex: Int?
        let debitIndex: Int?
        let creditIndex: Int?
        let currencyIndex: Int?
        let externalIDIndex: Int?
        let profileConvention: CSVAmountSignConvention

        init(headers: [String], profile: CSVImportProfile) {
            self.dateIndex = profile.columnIndex(in: headers, anyOf: profile.dateHeaderAliases)
            self.merchantIndex = profile.columnIndex(in: headers, anyOf: profile.merchantHeaderAliases)
            self.amountIndex = profile.columnIndex(in: headers, anyOf: profile.amountHeaderAliases)
            self.debitIndex = profile.columnIndex(in: headers, anyOf: profile.debitHeaderAliases)
            self.creditIndex = profile.columnIndex(in: headers, anyOf: profile.creditHeaderAliases)
            self.currencyIndex = profile.columnIndex(in: headers, anyOf: profile.currencyHeaderAliases)
            self.externalIDIndex = profile.columnIndex(in: headers, anyOf: profile.externalIDHeaderAliases)
            self.profileConvention = profile.amountSignConvention
        }

        /// True when the required columns for the profile are all
        /// present. Optional columns (currency, external ID) can be
        /// missing without invalidating the header.
        var isUsable: Bool {
            guard dateIndex != nil, merchantIndex != nil else { return false }
            switch profileConvention {
            case .separateDebitCreditColumns:
                return debitIndex != nil || creditIndex != nil
            case .negativeForDebit, .positiveForDebit:
                return amountIndex != nil
            }
        }
    }

    private static func parseRow(
        _ row: [String],
        lineNumber: Int,
        columns: ColumnMap,
        profile: CSVImportProfile
    ) -> Result<ParsedImportedRow, TransactionImportError> {

        guard let dateIndex = columns.dateIndex,
              let merchantIndex = columns.merchantIndex
        else {
            return .failure(.profileColumnMissing)
        }

        let rawMerchant = safeField(row, at: merchantIndex)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawMerchant.isEmpty else {
            return .failure(.missingMerchant)
        }

        guard let date = parseDate(
            safeField(row, at: dateIndex),
            formats: profile.dateFormats
        ) else {
            return .failure(.invalidDate)
        }

        let amountResult = parseAmount(
            row: row,
            columns: columns
        )
        let amount: Double
        switch amountResult {
        case .success(let signedAmount):
            amount = signedAmount
        case .failure(let error):
            return .failure(error)
        }

        let currencyCode: CurrencyCode
        if let idx = columns.currencyIndex {
            let raw = safeField(row, at: idx).trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty {
                currencyCode = profile.defaultCurrency
            } else if let parsed = CurrencyCode(rawValue: raw.uppercased()) {
                currencyCode = parsed
            } else {
                return .failure(.unsupportedCurrency)
            }
        } else {
            currencyCode = profile.defaultCurrency
        }

        let externalID: String? = columns.externalIDIndex.flatMap {
            let raw = safeField(row, at: $0).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }

        let normalized = MerchantNormalizer.normalize(rawMerchant)
        let fingerprint = TransactionImportDeduper.fingerprint(
            normalizedMerchant: normalized,
            amount: amount,
            date: date,
            currency: currencyCode
        )
        let category = MerchantCategoryInferrer.infer(from: normalized)

        return .success(ParsedImportedRow(
            lineNumber: lineNumber,
            rawMerchantName: rawMerchant,
            normalizedMerchantName: normalized,
            inferredCategory: category,
            amount: amount,
            currencyCode: currencyCode,
            date: date,
            externalTransactionID: externalID,
            fingerprint: fingerprint
        ))
    }

    // MARK: - Field parsers

    private static func safeField(_ row: [String], at index: Int) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index]
    }

    private static func parseAmount(
        row: [String],
        columns: ColumnMap
    ) -> Result<Double, TransactionImportError> {
        switch columns.profileConvention {
        case .negativeForDebit:
            guard let idx = columns.amountIndex else {
                return .failure(.missingAmount)
            }
            let raw = safeField(row, at: idx).trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return .failure(.missingAmount) }
            guard let value = parseDecimal(raw) else {
                return .failure(.invalidAmount)
            }
            return .success(value)

        case .positiveForDebit:
            guard let idx = columns.amountIndex else {
                return .failure(.missingAmount)
            }
            let raw = safeField(row, at: idx).trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return .failure(.missingAmount) }
            guard let value = parseDecimal(raw) else {
                return .failure(.invalidAmount)
            }
            // Flip sign so downstream code can always read "debit
            // = negative" without knowing which profile produced it.
            return .success(-value)

        case .separateDebitCreditColumns:
            let debitRaw = columns.debitIndex.map {
                safeField(row, at: $0).trimmingCharacters(in: .whitespaces)
            } ?? ""
            let creditRaw = columns.creditIndex.map {
                safeField(row, at: $0).trimmingCharacters(in: .whitespaces)
            } ?? ""

            if !debitRaw.isEmpty {
                guard let debit = parseDecimal(debitRaw) else {
                    return .failure(.invalidAmount)
                }
                return .success(-abs(debit))
            }
            if !creditRaw.isEmpty {
                guard let credit = parseDecimal(creditRaw) else {
                    return .failure(.invalidAmount)
                }
                return .success(abs(credit))
            }
            return .failure(.missingAmount)
        }
    }

    /// Parses an amount string with optional `$`, spaces, parens
    /// (for negative amounts), and thousands separators. Rejects
    /// everything else rather than silently coercing to zero.
    private static func parseDecimal(_ raw: String) -> Double? {
        var cleaned = raw
        cleaned.removeAll { $0 == "$" || $0 == "€" || $0 == "£" || $0 == " " }

        var isNegative = false
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            isNegative = true
            cleaned.removeFirst()
            cleaned.removeLast()
        }
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned) else { return nil }
        return isNegative ? -value : value
    }

    private static func parseDate(
        _ raw: String,
        formats: [String]
    ) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    // MARK: - Transaction construction

    @MainActor
    private static func makeTransaction(
        from parsed: ParsedImportedRow,
        account: Account,
        homeCurrency: CurrencyCode,
        source: TransactionImportSource,
        now: Date
    ) -> Transaction {
        // For cross-currency imports we do NOT invent an FX rate.
        // The user's applied rate is stored as unverified until they
        // either confirm it manually or a verified source attaches.
        let sameCurrency = parsed.currencyCodeMatches(homeCurrency)

        let appliedRate = sameCurrency ? 1.0 : 0.0
        let convertedAmount = sameCurrency ? parsed.amount : 0.0

        return Transaction(
            merchantName: parsed.rawMerchantName,
            originalAmount: parsed.amount,
            originalCurrency: parsed.currencyCode,
            convertedAmount: convertedAmount,
            homeCurrency: homeCurrency,
            appliedExchangeRate: appliedRate,
            midMarketRate: 0,
            date: parsed.date,
            category: parsed.inferredCategory,
            jurisdiction: account.jurisdiction,
            notes: "",
            isTaxDeductible: false,
            isFinanceKitImported: false,
            createdAt: now,
            appliedRateProvenance: sameCurrency ? nil : SourceProvenance.importedRateUnverified(accessedAt: now),
            midMarketRateProvenance: nil,
            normalizedMerchantName: parsed.normalizedMerchantName,
            importSource: source,
            externalTransactionID: parsed.externalTransactionID,
            importedAt: now,
            importFingerprint: parsed.fingerprint,
            account: account,
            taxDocument: nil
        )
    }
}

// MARK: - Helpers

extension ParsedImportedRow {

    /// Convenience equality check so the `makeTransaction`
    /// branching stays readable.
    fileprivate func currencyCodeMatches(_ other: CurrencyCode) -> Bool {
        currencyCode == other
    }
}

extension SourceProvenance {

    /// Provenance label attached to the applied exchange rate on a
    /// cross-currency CSV import. The rate is unknown — NomadFi
    /// doesn't invent one — so the label explicitly reads
    /// "unverified".
    static func importedRateUnverified(accessedAt: Date) -> SourceProvenance {
        SourceProvenance(
            name: "CSV import — rate not captured",
            urlString: nil,
            type: .userEntered,
            confidence: .unverified,
            jurisdiction: .unknown,
            accessedAt: accessedAt,
            notes: "CSV row didn't include an exchange rate. NomadFi treats imported cross-currency rates as unverified until the user confirms them manually."
        )
    }
}
