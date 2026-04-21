// SourceProvenanceTests.swift
// NomadFi
//
// Tests for Phase 1 source-governance primitives: confidence labels,
// the open exchange-rate API provenance, Account fee provenance defaults,
// and the pure freshness policy.

import Foundation
import Testing

@testable import NomadFi

struct SourceProvenanceTests {

    // MARK: - Exchange-rate provenance

    @Test("Open exchange-rate API is indicative, never verified")
    func openAPIIsIndicative() {
        let provenance = SourceProvenance.openExchangeRatesAPI(accessedAt: .now)

        #expect(provenance.confidence == .indicative)
        #expect(provenance.type == .prototypeAPI)
        #expect(provenance.confidence.isVerified == false)
        #expect(provenance.urlString == "https://open.er-api.com/v6/latest/")
        #expect(provenance.jurisdiction == .crossBorder)
    }

    @Test("Mock exchange-rate snapshots carry sample-data provenance")
    func mockServiceCarriesSampleProvenance() async throws {
        let service = MockExchangeRateService(simulatedDelay: .zero)
        let snapshots = try await service.fetchAllRates(for: [.usd, .cad])

        #expect(!snapshots.isEmpty)
        for snapshot in snapshots {
            #expect(snapshot.sourceProvenance.type == .sampleData)
            #expect(snapshot.sourceProvenance.confidence == .indicative)
        }
    }

    // MARK: - Account fee provenance

    @Test("User-entered account fees default to userProvided, not verified")
    func accountFeeDefaultsToUserProvided() {
        let account = Account(
            name: "Chase Freedom Rise",
            institutionName: "JPMorgan Chase",
            accountType: .creditCard,
            currencyCode: .usd,
            balance: 0,
            jurisdiction: "US",
            foreignTransactionFeePercent: 3.0
        )

        let provenance = account.foreignTransactionFeeProvenance
        #expect(provenance.confidence == .userProvided)
        #expect(provenance.confidence.isVerified == false)
        #expect(provenance.type == .userEntered)
    }

    @Test("Verified primary account fee is reported as verified")
    func accountFeeVerifiedPrimary() {
        let verifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let account = Account(
            name: "CIBC Dividend Cash Back",
            institutionName: "CIBC",
            accountType: .creditCard,
            currencyCode: .cad,
            balance: 0,
            jurisdiction: "CA",
            foreignTransactionFeePercent: 2.5,
            foreignTransactionFeeSourceName: "CIBC Dividend Cash Back Disclosure",
            foreignTransactionFeeSourceURL: "https://www.cibc.com/",
            foreignTransactionFeeSourceConfidence: .verifiedPrimary,
            foreignTransactionFeeSourceVerifiedAt: verifiedAt
        )

        let provenance = account.foreignTransactionFeeProvenance
        #expect(provenance.confidence == .verifiedPrimary)
        #expect(provenance.confidence.isVerified)
        #expect(provenance.type == .issuerDisclosure)
        #expect(provenance.accessedAt == verifiedAt)
    }

    // MARK: - Display labels

    @Test("Verified-primary renders as the short Verified label")
    func verifiedPrimaryDisplayLabel() {
        #expect(SourceConfidence.verifiedPrimary.displayLabel == "Verified")
        #expect(SourceConfidence.verifiedSecondary.displayLabel == "Verified")
    }

    @Test("Unverified-flavoured cases never read as certain")
    func nonVerifiedDisplayLabels() {
        #expect(SourceConfidence.userProvided.displayLabel == "User provided")
        #expect(SourceConfidence.indicative.displayLabel == "Indicative")
        #expect(SourceConfidence.unverified.displayLabel == "Unverified")

        #expect(SourceConfidence.userProvided.isVerified == false)
        #expect(SourceConfidence.indicative.isVerified == false)
        #expect(SourceConfidence.unverified.isVerified == false)
    }

    // MARK: - Freshness policy

    @Test("Old issuer card terms are reported as stale")
    func oldCardTermsAreStale() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Verified ~60 days ago — past the ~30-day window for issuer terms.
        let verifiedAt = now.addingTimeInterval(-60 * 60 * 24 * 60)

        let status = SourceFreshness.status(
            verifiedAt: verifiedAt,
            domain: .issuerCardTerms,
            now: now
        )

        #expect(status == .stale)
    }

    @Test("Recently verified card terms are fresh")
    func recentCardTermsAreFresh() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Verified ~2 days ago — well inside the 30-day window.
        let verifiedAt = now.addingTimeInterval(-60 * 60 * 24 * 2)

        let status = SourceFreshness.status(
            verifiedAt: verifiedAt,
            domain: .issuerCardTerms,
            now: now
        )

        #expect(status == .fresh)
    }

    @Test("Missing verification date is unknown, never fresh")
    func missingVerificationDateIsUnknown() {
        let status = SourceFreshness.status(
            verifiedAt: nil,
            domain: .issuerCardTerms,
            now: .now
        )

        #expect(status == .unknown)
        #expect(status != .fresh)
    }

    @Test("Tax/residency rules return unknown under the rolling-window check")
    func taxRulesUseYearlyVerification() {
        // Tax rules are tied to the current tax year, not a rolling window.
        // The API must not mislead callers into treating any rolling-window
        // result as fresh for tax data.
        let status = SourceFreshness.status(
            verifiedAt: .now,
            domain: .taxResidencyRules,
            now: .now
        )

        #expect(status == .unknown)
    }
}
