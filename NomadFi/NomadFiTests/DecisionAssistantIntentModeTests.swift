// DecisionAssistantIntentModeTests.swift
// NomadFi
//
// Runtime coverage for the iOS 18+ `supportedModes` hand-off on each
// Decision Assistant App Intent. The previous implementation relied
// on the now-deprecated `openAppWhenRun` flag; this module pins the
// mode declarations so future refactors can't silently regress a
// voice-only intent into opening the app, or vice-versa.
//
// The assertions use `OptionSet.contains(_:)` rather than raw-value
// comparisons so they survive any internal reshuffling of
// `IntentModes`' bitmask — only the public option membership matters.

import AppIntents
import Testing

@testable import NomadFi

struct DecisionAssistantIntentModeTests {

    // MARK: - Foreground (navigation) intents

    @Test("OpenDecisionAssistantIntent opens the app via .foreground(.immediate)")
    func openDecisionAssistantIsForeground() {
        let modes = OpenDecisionAssistantIntent.supportedModes
        #expect(modes.contains(.foreground))
        #expect(!modes.contains(.background))
    }

    @Test("ContinueAmazonArrivalDecisionIntent opens the app via .foreground(.immediate)")
    func continueAmazonArrivalIsForeground() {
        let modes = ContinueAmazonArrivalDecisionIntent.supportedModes
        #expect(modes.contains(.foreground))
        #expect(!modes.contains(.background))
    }

    // MARK: - Background (voice-only) intents

    @Test("ActiveCardIntent runs in background — voice-only, never surfaces the app")
    func activeCardIsBackground() {
        let modes = ActiveCardIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    @Test("ReviewAmazonArrivalDecisionIntent runs in background — voice summary only")
    func reviewAmazonArrivalIsBackground() {
        let modes = ReviewAmazonArrivalDecisionIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    // MARK: - Supporting (non-Decision-Assistant) voice intents

    @Test("CheckBudgetIntent runs in background")
    func checkBudgetIsBackground() {
        let modes = CheckBudgetIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    @Test("CheckNetWorthIntent runs in background")
    func checkNetWorthIsBackground() {
        let modes = CheckNetWorthIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }

    @Test("LogExpenseIntent runs in background")
    func logExpenseIsBackground() {
        let modes = LogExpenseIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(!modes.contains(.foreground))
    }
}
