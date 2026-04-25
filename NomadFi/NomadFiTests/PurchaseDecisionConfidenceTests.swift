// PurchaseDecisionConfidenceTests.swift
// NomadFi
//
// Pure-logic coverage for the Phase 3 follow-through confidence
// derivation, including the cross-border guidance the engine
// emits when the travel signal is positive. The engine reads
// `Account` SwiftData rows, so this suite is `@MainActor`-bound
// and uses freshly-built `Account`s without inserting them into a
// `ModelContainer` (matches the existing `PurchaseDecisionEngineTests`
// pattern).

import Foundation
import Testing

@testable import NomadFi

@MainActor
struct PurchaseDecisionConfidenceTests {

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
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private static let now = date(year: 2026, month: 4, day: 24)

    private func context(
        amount: Double? = 80,
        currency: CurrencyCode = .usd,
        category: MerchantCategory = .general,
        location: String = ""
    ) -> PurchaseContext {
        PurchaseContext(
            merchantName: "Target",
            category: category,
            amount: amount,
            currencyCode: currency,
            countryCode: location,
            timingText: ""
        )
    }

    private func checkingAccount(
        currency: CurrencyCode = .usd,
        balance: Double? = 1_000
    ) -> Account {
        Account(
            name: "Chase Checking",
            institutionName: "Chase",
            accountType: .checking,
            currencyCode: currency,
            currentBalance: balance
        )
    }

    /// Credit-card factory. `feeIsVerified == true` builds an
    /// account whose persisted FX-fee source confidence is
    /// `.verifiedPrimary` and whose `verifiedAt` is fresh, so the
    /// engine treats the fee as verified. `false` leaves the source
    /// fields blank — the engine treats the fee as unverified
    /// (the user-provided default).
    private func creditCard(
        currency: CurrencyCode = .usd,
        creditLimit: Double? = 5_000,
        currentBalance: Double? = 500,
        feePercent: Double = 0,
        feeIsVerified: Bool = true
    ) -> Account {
        Account(
            name: "Rewards Card",
            institutionName: "Issuer Bank",
            accountType: .creditCard,
            currencyCode: currency,
            foreignTransactionFeePercent: feePercent,
            foreignTransactionFeeSourceName: feeIsVerified ? "Issuer card terms" : nil,
            foreignTransactionFeeSourceURL: feeIsVerified ? "https://example.com/terms" : nil,
            foreignTransactionFeeSourceConfidence: feeIsVerified ? .verifiedPrimary : nil,
            foreignTransactionFeeSourceVerifiedAt: feeIsVerified ? Self.now : nil,
            statementPeriodStartDate: Self.date(year: 2026, month: 4, day: 1),
            statementClosingDate: Self.date(year: 2026, month: 4, day: 28),
            paymentDueDate: Self.date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: Self.date(year: 2026, month: 4, day: 21),
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            financialSnapshotUpdatedAt: PurchaseDecisionConfidenceTests.now,
            financialSnapshotSource: .userSnapshot
        )
    }

    // MARK: - High confidence

    @Test("Same-currency, same-currency-account, no location hint, no travel category, no checks ⇒ .high confidence")
    func sameCurrencyCleanContextProducesHighConfidence() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(category: .general, location: ""),
            accounts: [checkingAccount()],
            now: Self.now
        )
        #expect(decision.recommendation != nil)
        #expect(decision.confidence == .high)
        #expect(decision.travelContext.isLikelyCrossBorder == false)
    }

    // MARK: - Moderate confidence

    @Test("Travel category alone (same currency) drops confidence to .moderate even though FX is verified")
    func travelCategoryProducesModerateConfidence() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(category: .travel),
            accounts: [checkingAccount()],
            now: Self.now
        )
        #expect(decision.recommendation != nil)
        #expect(decision.confidence == .moderate)
        #expect(decision.travelContext.isTravelCategory == true)
        #expect(decision.travelContext.isLikelyCrossBorder == true)
    }

    @Test("Location hint alone (same currency, no travel category) drops confidence to .moderate")
    func locationHintProducesModerateConfidence() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(location: "Toronto"),
            accounts: [checkingAccount()],
            now: Self.now
        )
        #expect(decision.recommendation != nil)
        #expect(decision.confidence == .moderate)
        #expect(decision.travelContext.hasLocationHint == true)
    }

    @Test("Cross-currency with VERIFIED FX produces .moderate, not .lowOrUnverified")
    func crossCurrencyVerifiedFXIsModerate() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(currency: .cad),
            accounts: [
                creditCard(
                    currency: .usd,
                    feePercent: 2.5,
                    feeIsVerified: true
                ),
            ],
            now: Self.now
        )
        #expect(decision.recommendation != nil)
        #expect(decision.confidence == .moderate)
    }

    // MARK: - Low / unverified

    @Test("Cross-currency with UNVERIFIED FX drops confidence to .lowOrUnverified")
    func crossCurrencyUnverifiedFXIsLow() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(currency: .cad),
            accounts: [
                creditCard(
                    currency: .usd,
                    feePercent: 2.5,
                    feeIsVerified: false
                ),
            ],
            now: Self.now
        )
        #expect(decision.recommendation != nil)
        #expect(decision.confidence == .lowOrUnverified)
    }

    @Test("No recommendation at all (no payment accounts) ⇒ .lowOrUnverified")
    func missingRecommendationIsLow() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(),
            accounts: [],
            now: Self.now
        )
        #expect(decision.recommendation == nil)
        #expect(decision.confidence == .lowOrUnverified)
    }

    // MARK: - Cross-border guidance fires only when warranted

    @Test("No travel signal ⇒ DCC reminder absent from warnings and from the missing-data checklist")
    func noTravelSignalNoCrossBorderCopy() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(),
            accounts: [checkingAccount()],
            now: Self.now
        )
        let joined = (decision.whenNotToUseWarnings + decision.missingDataChecklist).joined(separator: "\n")
        #expect(!joined.localizedStandardContains("Dynamic Currency Conversion"))
        #expect(!joined.localizedStandardContains("dispute process"))
    }

    @Test("Travel signal positive ⇒ DCC reminder fires in warnings, FX/dispute/acceptance reminders fire in checklist")
    func travelSignalProducesCrossBorderCopy() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(category: .travel, location: "Madrid"),
            accounts: [checkingAccount()],
            now: Self.now
        )
        let warnings = decision.whenNotToUseWarnings.joined(separator: "\n")
        let checks = decision.missingDataChecklist.joined(separator: "\n")
        #expect(warnings.localizedStandardContains("Dynamic Currency Conversion"))
        #expect(checks.localizedStandardContains("foreign-currency conversion"))
        #expect(checks.localizedStandardContains("dispute"))
        #expect(checks.localizedStandardContains("backup payment method"))
    }

    // MARK: - Copy guard on confidence + cross-border surfaces

    @Test("Confidence labels and explanations never use prohibited / marketing language")
    func confidenceCopyHasNoProhibitedPhrases() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(category: .travel, location: "Lisbon"),
            accounts: [
                creditCard(currency: .usd, feeIsVerified: false),
                checkingAccount(),
            ],
            now: Self.now
        )

        let prohibited: [String] = [
            "guaranteed",
            "best card",
            "best account",
            "always cheaper",
            "always more expensive",
            "score will increase",
            "carry a balance",
            "always best",
            "lowest fee",
        ]

        var surfaces: [String] = []
        surfaces.append(decision.confidence.summary)
        surfaces.append(contentsOf: PurchaseDecisionConfidence.allCases.map(\.summary))
        surfaces.append(contentsOf: PurchaseDecisionConfidence.allCases.map(\.displayLabel))
        surfaces.append(contentsOf: decision.confidenceExplanations)
        surfaces.append(contentsOf: decision.whenNotToUseWarnings)
        surfaces.append(contentsOf: decision.missingDataChecklist)

        for text in surfaces {
            let lower = text.lowercased()
            for phrase in prohibited {
                #expect(
                    !lower.contains(phrase),
                    "Surface must not contain \"\(phrase)\": \(text)"
                )
            }
        }
    }

    // MARK: - Citation publishers

    @Test("Citations on a cross-border purchase ship CFPB / HelpWithMyBank / FCAC / Visa / Mastercard")
    func crossBorderCitationsAreOfficial() {
        let decision = PurchaseDecisionEngine.decide(
            context: context(currency: .usd, category: .travel, location: "London"),
            accounts: [checkingAccount()],
            now: Self.now
        )
        let publishers = Set(decision.citations.map(\.publisher))
        let required: Set<String> = [
            "CFPB",
            "HelpWithMyBank",
            "FCAC",
            "Visa",
            "Mastercard",
        ]
        #expect(required.isSubset(of: publishers))
    }
}
