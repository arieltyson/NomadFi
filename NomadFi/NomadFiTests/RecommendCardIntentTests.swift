// RecommendCardIntentTests.swift
// NomadFi
//
// Focused coverage for the two new voice-parity intents:
//
//   - `RecommendCardIntent` — runs `PurchaseDecisionEngine` against
//     the user's saved accounts for a typed purchase context.
//   - `ReviewCreditTimingIntent` — runs `CreditTimingDecisionEngine`.
//
// These tests do not touch SwiftData. They exercise the pure
// dialog builders in `DecisionAssistantIntentDialog`, the App Intents
// adapters for `MerchantCategory` and `CurrencyCode`, and the
// `supportedModes` declarations. That keeps them off the SwiftData
// parallel-init risk class and leaves persistence coverage to the
// already-serialized record suites.

import AppIntents
import Foundation
import Testing

@testable import NomadFi

struct RecommendCardIntentTests {

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

    private static let now = date(year: 2026, month: 4, day: 23)

    private static func baseContext(
        amount: Double? = 80,
        currency: CurrencyCode = .usd,
        category: MerchantCategory = .groceries,
        merchant: String = "Target",
        country: String = "San Francisco"
    ) -> PurchaseContext {
        PurchaseContext(
            merchantName: merchant,
            category: category,
            amount: amount,
            currencyCode: currency,
            countryCode: country,
            timingText: ""
        )
    }

    private static func usdChecking(
        balance: Double = 500
    ) -> Account {
        Account(
            name: "USD Checking",
            institutionName: "Neutral Bank",
            accountType: .checking,
            currencyCode: .usd,
            currentBalance: balance
        )
    }

    private static func usdCreditCard(
        name: String = "Rewards Card",
        limit: Double = 5_000,
        balance: Double = 500,
        snapshotUpdatedAt: Date = RecommendCardIntentTests.now,
        foreignTransactionFeePercent: Double = 0,
        currency: CurrencyCode = .usd
    ) -> Account {
        Account(
            name: name,
            institutionName: "Issuer Bank",
            accountType: .creditCard,
            currencyCode: currency,
            foreignTransactionFeePercent: foreignTransactionFeePercent,
            statementPeriodStartDate: date(year: 2026, month: 4, day: 1),
            statementClosingDate: date(year: 2026, month: 4, day: 28),
            paymentDueDate: date(year: 2026, month: 5, day: 25),
            statementScheduleLastConfirmedAt: date(year: 2026, month: 4, day: 21),
            creditLimit: limit,
            currentBalance: balance,
            financialSnapshotUpdatedAt: snapshotUpdatedAt,
            financialSnapshotSource: .userSnapshot
        )
    }

    private static func purchaseDecision(
        context: PurchaseContext? = nil,
        accounts: [Account]
    ) -> PurchaseDecision {
        PurchaseDecisionEngine.decide(
            context: context ?? baseContext(),
            accounts: accounts,
            now: now
        )
    }

    // MARK: - Supported modes

    @Test("RecommendCardIntent runs in background — voice-only, never surfaces the app")
    func recommendCardIsBackground() {
        let modes = RecommendCardIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    @Test("ReviewCreditTimingIntent runs in background — voice summary only")
    func reviewCreditTimingIsBackground() {
        let modes = ReviewCreditTimingIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    // MARK: - AppEnum adapters

    @Test("MerchantCategoryAppEnum round-trips every MerchantCategory case")
    func merchantCategoryAdapterRoundTripsAllCases() {
        for core in MerchantCategory.allCases {
            let adapter = MerchantCategoryAppEnum(core)
            #expect(adapter.merchantCategory == core)
        }
    }

    @Test("MerchantCategoryAppEnum exposes a display representation for every case")
    func merchantCategoryAdapterHasDisplayForEveryCase() {
        for adapter in MerchantCategoryAppEnum.allCases {
            #expect(
                MerchantCategoryAppEnum.caseDisplayRepresentations[adapter] != nil,
                "Missing DisplayRepresentation for \(adapter)"
            )
        }
    }

    @Test("CurrencyCodeAppEnum round-trips every CurrencyCode case")
    func currencyCodeAdapterRoundTripsAllCases() {
        for core in CurrencyCode.allCases {
            let adapter = CurrencyCodeAppEnum(core)
            #expect(adapter.currencyCode == core)
        }
    }

    @Test("CurrencyCodeAppEnum exposes a display representation for every case")
    func currencyCodeAdapterHasDisplayForEveryCase() {
        for adapter in CurrencyCodeAppEnum.allCases {
            #expect(
                CurrencyCodeAppEnum.caseDisplayRepresentations[adapter] != nil,
                "Missing DisplayRepresentation for \(adapter)"
            )
        }
    }

    // MARK: - recommendCardAnswer — missing context

    @Test("Missing amount dialog asks for the amount instead of inventing one")
    func missingAmountDialogAsksForAmount() {
        let decision = PurchaseDecisionEngine.decide(
            context: Self.baseContext(amount: nil),
            accounts: [Self.usdChecking()],
            now: Self.now
        )
        let dialog = DecisionAssistantIntentDialog.recommendCardAnswer(
            decision: decision
        )
        #expect(dialog.localizedStandardContains("need the amount"))
        #expect(!dialog.localizedStandardContains("recommended"))
    }

    @Test("recommendCardMissingAmount string is stable and safe")
    func missingAmountStandaloneStringIsSafe() {
        let text = DecisionAssistantIntentDialog.recommendCardMissingAmount
            .lowercased()
        for banned in forbiddenPhrases {
            #expect(
                !text.contains(banned),
                "Missing-amount copy must not contain \"\(banned)\""
            )
        }
    }

    // MARK: - recommendCardAnswer — no accounts

    @Test("No payment accounts dialog names the setup path")
    func noAccountsDialog() {
        let decision = PurchaseDecisionEngine.decide(
            context: Self.baseContext(),
            accounts: [],
            now: Self.now
        )
        let dialog = DecisionAssistantIntentDialog.recommendCardAnswer(
            decision: decision
        )
        #expect(dialog.contains("Settings"))
        #expect(!dialog.localizedStandardContains("recommended option"))
    }

    // MARK: - recommendCardAnswer — ready with fallback

    @Test("Ready dialog announces the recommendation and the fallback")
    func readyDialogNamesRecommendationAndFallback() {
        let decision = Self.purchaseDecision(
            accounts: [Self.usdChecking(), Self.usdCreditCard()]
        )
        let dialog = DecisionAssistantIntentDialog.recommendCardAnswer(
            decision: decision
        )
        let rec = try! #require(decision.recommendation)
        #expect(dialog.contains(rec.accountName))
        #expect(dialog.localizedStandardContains("recommended option"))
        if let fallback = decision.fallback {
            #expect(dialog.contains(fallback.accountName))
            #expect(dialog.localizedStandardContains("fall back"))
        }
    }

    // MARK: - recommendCardAnswer — rewards-sensitive category triggers caveat

    @Test("Rewards-sensitive category triggers the verify-rewards caveat")
    func rewardsSensitiveCategoryAddsCaveat() {
        // `dining` is a rewards-sensitive category; engine picks the
        // same-currency debit account, so only the caveat should be
        // the differentiator from the base "ready" case.
        let decision = Self.purchaseDecision(
            context: Self.baseContext(category: .dining),
            accounts: [Self.usdChecking()]
        )
        let dialog = DecisionAssistantIntentDialog.recommendCardAnswer(
            decision: decision
        )
        #expect(dialog.localizedStandardContains("does not model verified rewards"))
    }

    // MARK: - recommendCardAnswer — FX unverified caveat

    @Test("Cross-currency recommendation surfaces an FX verification caveat")
    func crossCurrencyDialogAddsFXCaveat() {
        // USD checking on a CAD purchase: matchesPurchaseCurrency ==
        // false, FX fee unverified.
        let decision = Self.purchaseDecision(
            context: Self.baseContext(currency: .cad),
            accounts: [Self.usdChecking()]
        )
        let dialog = DecisionAssistantIntentDialog.recommendCardAnswer(
            decision: decision
        )
        #expect(dialog.localizedStandardContains("hasn't been verified")
                || dialog.localizedStandardContains("verify the final converted amount"))
    }

    // MARK: - recommendCardAnswer — forbidden language

    @Test("Dialog across ruling cases never contains forbidden score/debt language")
    func dialogNeverContainsForbiddenLanguage() {
        let samples: [PurchaseDecision] = [
            // Missing context
            PurchaseDecisionEngine.decide(
                context: Self.baseContext(amount: nil),
                accounts: [Self.usdChecking()],
                now: Self.now
            ),
            // No accounts
            PurchaseDecisionEngine.decide(
                context: Self.baseContext(),
                accounts: [],
                now: Self.now
            ),
            // Ready, debit primary, credit-card fallback
            Self.purchaseDecision(
                accounts: [Self.usdChecking(), Self.usdCreditCard()]
            ),
            // Ready, stale credit snapshot on portfolio
            Self.purchaseDecision(
                accounts: [
                    Self.usdChecking(),
                    Self.usdCreditCard(
                        snapshotUpdatedAt: Self.now
                            .addingTimeInterval(-60 * 60 * 24 * 60)
                    ),
                ]
            ),
            // Cross-currency — FX caveat path
            Self.purchaseDecision(
                context: Self.baseContext(currency: .cad),
                accounts: [Self.usdChecking()]
            ),
        ]

        for decision in samples {
            let dialog = DecisionAssistantIntentDialog
                .recommendCardAnswer(decision: decision)
                .lowercased()
            for banned in forbiddenPhrases {
                #expect(
                    !dialog.contains(banned),
                    "Forbidden phrase \"\(banned)\" leaked into dialog for ruling \(decision.ruling)"
                )
            }
        }
    }

    // MARK: - Credit timing dialog

    @Test("Credit timing dialog without credit cards points at Settings")
    func creditTimingDialogNoCards() {
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [Self.usdChecking()],
            now: Self.now
        )
        let dialog = DecisionAssistantIntentDialog
            .creditTimingReview(decision: decision)
        #expect(dialog.contains("Settings"))
        #expect(decision.ruling == .noCreditCardsOnFile)
    }

    @Test("Credit timing dialog for a near-limit card names the card and says avoid more spend")
    func creditTimingDialogNearLimit() {
        let nearLimit = Self.usdCreditCard(limit: 100, balance: 95)
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [nearLimit],
            now: Self.now
        )
        let dialog = DecisionAssistantIntentDialog
            .creditTimingReview(decision: decision)
        #expect(decision.ruling == .someNearLimit)
        #expect(dialog.contains(nearLimit.name))
        #expect(dialog.localizedStandardContains("near its credit limit"))
        #expect(dialog.localizedStandardContains("avoid additional spend"))
    }

    @Test("Credit timing dialog for stale-snapshot card surfaces missingData guidance")
    func creditTimingDialogMissingData() {
        // Stale snapshot forces `.snapshotStale` per-card ruling,
        // which aggregates up to `.missingData` at the portfolio
        // level.
        let stale = Self.usdCreditCard(
            snapshotUpdatedAt: Self.now
                .addingTimeInterval(-60 * 60 * 24 * 60)
        )
        let decision = CreditTimingDecisionEngine.decide(
            accounts: [stale],
            now: Self.now
        )
        let dialog = DecisionAssistantIntentDialog
            .creditTimingReview(decision: decision)
        #expect(decision.ruling == .missingData)
        #expect(dialog.localizedStandardContains("more data"))
    }

    @Test("Credit timing dialog never contains forbidden score/debt language")
    func creditTimingDialogNeverContainsForbiddenLanguage() {
        let scenarios: [[Account]] = [
            [Self.usdChecking()], // no cards
            [Self.usdCreditCard()], // ready
            [Self.usdCreditCard(limit: 100, balance: 95)], // near limit
            [Self.usdCreditCard(limit: 10_000, balance: 5_000)], // pay down
            [Self.usdCreditCard( // stale
                snapshotUpdatedAt: Self.now
                    .addingTimeInterval(-60 * 60 * 24 * 60)
            )],
        ]

        for accounts in scenarios {
            let decision = CreditTimingDecisionEngine.decide(
                accounts: accounts,
                now: Self.now
            )
            let dialog = DecisionAssistantIntentDialog
                .creditTimingReview(decision: decision)
                .lowercased()
            for banned in forbiddenPhrases {
                #expect(
                    !dialog.contains(banned),
                    "Forbidden phrase \"\(banned)\" leaked into credit-timing dialog for ruling \(decision.ruling)"
                )
            }
        }
    }

    // MARK: - Shortcut catalog

    @Test("App Shortcuts catalog count is within Apple's 10-item soft cap")
    func shortcutsCatalogCountIsBounded() {
        // AppShortcut does not expose its components publicly at
        // runtime, so we can't assert the specific intents are
        // registered from here. The build-time `ExtractAppIntentsMetadata`
        // step emits `Metadata.appintents` which the Decisions
        // surface already depends on; runtime here only pins the
        // catalog size invariant.
        #expect(NomadFiShortcuts.appShortcuts.count <= 10)
        #expect(!NomadFiShortcuts.appShortcuts.isEmpty)
    }

    // MARK: - Fixtures

    /// Phrases NomadFi's voice surface must never emit. Centralised so
    /// every new dialog path is vetted against the same list.
    private static let forbiddenPhrases: [String] = [
        "guaranteed",
        "guarantee",
        "score will increase",
        "will improve your score",
        "carry a balance",
        "best card",
        "lowest fee",
        "always best",
    ]

    private var forbiddenPhrases: [String] { Self.forbiddenPhrases }
}
