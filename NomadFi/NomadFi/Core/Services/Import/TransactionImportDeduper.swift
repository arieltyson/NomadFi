// TransactionImportDeduper.swift
// NomadFi
//
// Pure dedupe engine for CSV imports.
//
// Two signals, in order of confidence:
//
//   1. **External transaction ID match.** If the row carries an
//      `externalTransactionID` and the same ID already exists on
//      the target account, it's definitely a duplicate.
//
//   2. **Fingerprint match.** For rows without an external ID, the
//      fingerprint is `"<normalized merchant>|<amount to 2dp>|<ISO
//      date>|<currency>"`. The deduper accepts a fingerprint match
//      as duplicate when the stored transaction's date is within a
//      configurable day-window (default 3) — bank posting dates can
//      shift a day or two between exports, but amount and merchant
//      stay stable.
//
// No side effects: the engine never writes to SwiftData. Call sites
// drive the actual insert.

import Foundation

/// Pure dedupe logic.
enum TransactionImportDeduper {

    /// Maximum allowed date drift between a proposed row and an
    /// existing fingerprint match. Three days covers weekend posts
    /// and timezone skew without collapsing genuinely distinct
    /// same-merchant charges.
    static let defaultFingerprintDayWindow: Int = 3

    /// Reason text the preview uses when a row is labelled
    /// duplicate. Split by path so the UI can explain *why*.
    enum DuplicateReason: Sendable, Equatable {
        case externalIDMatch
        case fingerprintMatch(dayDelta: Int)

        var displayLabel: String {
            switch self {
            case .externalIDMatch:
                "Matches an existing transaction by external ID."
            case .fingerprintMatch(let delta):
                "Same merchant, amount, and currency within \(delta) day\(delta == 1 ? "" : "s") of an existing transaction."
            }
        }
    }

    /// Checks whether `parsed` duplicates any of the
    /// `existingTransactions` attached to the same account. Returns
    /// the reason when it does; `nil` otherwise. Callers pass the
    /// already-filtered list of same-account transactions so the
    /// deduper stays pure value logic.
    static func duplicateReason(
        for parsed: ParsedImportedRow,
        in existingTransactions: [Transaction],
        dayWindow: Int = defaultFingerprintDayWindow,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> DuplicateReason? {
        // 1. External ID match — strongest signal.
        if let externalID = parsed.externalTransactionID,
           !externalID.isEmpty,
           existingTransactions.contains(where: { $0.externalTransactionID == externalID })
        {
            return .externalIDMatch
        }

        // 2. Fingerprint match within the day window.
        for existing in existingTransactions {
            guard let existingFingerprint = existing.importFingerprint
                    ?? Self.synthesizeFingerprint(from: existing)
            else {
                continue
            }

            // Fast reject: fingerprints disagree on merchant /
            // amount / currency.
            guard fingerprintsMatchOnMerchantAmountCurrency(
                existingFingerprint,
                parsed.fingerprint
            ) else {
                continue
            }

            // Slow reject: date drift above the window.
            var dayCalendar = calendar
            dayCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
            let dayDelta = absoluteDayDelta(
                from: existing.date,
                to: parsed.date,
                calendar: dayCalendar
            )
            if dayDelta <= dayWindow {
                return .fingerprintMatch(dayDelta: dayDelta)
            }
        }

        return nil
    }

    /// Builds the deterministic fingerprint string stored on
    /// `Transaction.importFingerprint` / compared by the deduper.
    /// Called by the import service before committing, and by the
    /// deduper when comparing against rows that pre-date this
    /// schema (synthesized on the fly).
    static func fingerprint(
        normalizedMerchant: String,
        amount: Double,
        date: Date,
        currency: CurrencyCode,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> String {
        var isoCalendar = calendar
        isoCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let components = isoCalendar.dateComponents([.year, .month, .day], from: date)
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        let amountRounded = (amount * 100).rounded() / 100
        let amountString = String(format: "%.2f", amountRounded)
        let isoDate = String(format: "%04d-%02d-%02d", y, m, d)
        return "\(normalizedMerchant)|\(amountString)|\(isoDate)|\(currency.rawValue)"
    }

    // MARK: - Private

    /// Builds a fingerprint for a legacy row that doesn't have one
    /// stored yet. Uses whichever normalized merchant is on file,
    /// falling back to the raw merchant.
    private static func synthesizeFingerprint(
        from transaction: Transaction
    ) -> String? {
        let merchant = transaction.normalizedMerchantName?.nilIfEmpty
            ?? MerchantNormalizer.normalize(transaction.merchantName)
        guard !merchant.isEmpty else { return nil }
        let currency = transaction.originalCurrency ?? .usd
        return fingerprint(
            normalizedMerchant: merchant,
            amount: transaction.originalAmount,
            date: transaction.date,
            currency: currency
        )
    }

    /// Checks the first three `|`-separated segments (merchant,
    /// amount, currency — but not date). The date is compared
    /// separately through the day window.
    private static func fingerprintsMatchOnMerchantAmountCurrency(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        let lhsParts = lhs.split(separator: "|", omittingEmptySubsequences: false)
        let rhsParts = rhs.split(separator: "|", omittingEmptySubsequences: false)
        guard lhsParts.count == 4, rhsParts.count == 4 else { return false }
        return lhsParts[0] == rhsParts[0]
            && lhsParts[1] == rhsParts[1]
            && lhsParts[3] == rhsParts[3]
    }

    /// Absolute number of days between two dates.
    private static func absoluteDayDelta(
        from lhs: Date,
        to rhs: Date,
        calendar: Calendar
    ) -> Int {
        let components = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lhs),
            to: calendar.startOfDay(for: rhs)
        )
        return abs(components.day ?? Int.max)
    }
}

// MARK: - Helpers

private extension String {

    /// Returns `self` when non-empty, else `nil`. Keeps the
    /// synthesize-fingerprint fallback readable.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
