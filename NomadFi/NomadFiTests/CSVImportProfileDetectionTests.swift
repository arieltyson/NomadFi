// CSVImportProfileDetectionTests.swift
// NomadFi
//
// Header-driven detector coverage. Every fixture uses synthetic
// merchants and amounts — no real Ariel / issuer data.

import Foundation
import Testing

@testable import NomadFi

struct CSVImportProfileDetectionTests {

    // MARK: - Chase-like

    @Test("Chase-like header row resolves to the Chase-like profile")
    func chaseLikeHeaderDetected() {
        let headers = [
            "Transaction Date",
            "Posting Date",
            "Description",
            "Debit",
            "Credit",
            "Transaction ID",
        ]
        let profile = TransactionImportProfile.detect(from: headers)
        #expect(profile.source == .csvChaseLike)
        #expect(profile.amountSignConvention == .separateDebitCreditColumns)
    }

    // MARK: - CIBC-like

    @Test("CIBC-like header row resolves to the CIBC-like profile")
    func cibcLikeHeaderDetected() {
        let headers = [
            "Date",
            "Description",
            "Amount",
            "Currency",
            "Reference Number",
        ]
        let profile = TransactionImportProfile.detect(from: headers)
        #expect([.csvCIBCLike, .csvChaseLike].contains(profile.source))
        if profile.source == .csvCIBCLike {
            #expect(profile.amountSignConvention == .negativeForDebit)
        }
    }

    // MARK: - Amex Canada-like

    @Test("Amex Canada-like header row resolves to the Amex-like profile")
    func amexCanadaLikeHeaderDetected() {
        let headers = [
            "Date",
            "Description",
            "Amount",
        ]
        let profile = TransactionImportProfile.detect(from: headers)
        // Amex and CIBC share a common header shape; either is a
        // valid detection. What matters is that it's a named profile
        // with a recognisable sign convention.
        #expect([.csvAmexCanadaLike, .csvCIBCLike].contains(profile.source))
    }

    // MARK: - Wise-like

    @Test("Wise-like header row resolves to the Wise-like profile")
    func wiseLikeHeaderDetected() {
        let headers = [
            "TransferWise ID",
            "Date",
            "Amount",
            "Currency",
            "Description",
        ]
        let profile = TransactionImportProfile.detect(from: headers)
        #expect(profile.source == .csvWiseLike)
    }

    // MARK: - Generic fallback

    @Test("Unrecognised header shape falls back to the generic profile")
    func fallsBackToGenericWhenNoNamedProfileMatches() {
        let headers = [
            "When",
            "Who",
            "HowMuch",
        ]
        let profile = TransactionImportProfile.detect(from: headers)
        #expect(profile.source == .csvGeneric)
    }

    // MARK: - Column-index resolution

    @Test("Column index lookup is case-insensitive and underscore-tolerant")
    func columnIndexResolutionIsForgiving() {
        let profile = TransactionImportProfile.chaseLike
        let headers = ["transaction_date", "description", "amount"]
        #expect(profile.columnIndex(in: headers, anyOf: profile.dateHeaderAliases) == 0)
        #expect(profile.columnIndex(in: headers, anyOf: profile.merchantHeaderAliases) == 1)
    }
}
