// IntentMetadataTests.swift
// NomadFi
//
// App Store Connect rejects a build whose App Intent metadata contains
// the word "Apple" (ITMS-90626). This pins every intent's title and
// description against it.

import AppIntents
import Foundation
import Testing

@testable import NomadFi

struct IntentMetadataTests {

    private static let metadata: [(String, LocalizedStringResource, IntentDescription?)] = [
        ("ActiveCardIntent", ActiveCardIntent.title, ActiveCardIntent.description),
        ("CaptureDecisionDraftIntent", CaptureDecisionDraftIntent.title, CaptureDecisionDraftIntent.description),
        ("CheckBudgetIntent", CheckBudgetIntent.title, CheckBudgetIntent.description),
        ("CheckNetWorthIntent", CheckNetWorthIntent.title, CheckNetWorthIntent.description),
        ("ContinueAmazonArrivalDecisionIntent", ContinueAmazonArrivalDecisionIntent.title, ContinueAmazonArrivalDecisionIntent.description),
        ("LogExpenseIntent", LogExpenseIntent.title, LogExpenseIntent.description),
        ("OpenAIIntakeIntent", OpenAIIntakeIntent.title, OpenAIIntakeIntent.description),
        ("OpenDecisionAssistantIntent", OpenDecisionAssistantIntent.title, OpenDecisionAssistantIntent.description),
        ("RecommendCardIntent", RecommendCardIntent.title, RecommendCardIntent.description),
        ("ReviewAmazonArrivalDecisionIntent", ReviewAmazonArrivalDecisionIntent.title, ReviewAmazonArrivalDecisionIntent.description),
        ("ReviewCreditTimingIntent", ReviewCreditTimingIntent.title, ReviewCreditTimingIntent.description),
        ("StartAIIntakeIntent", StartAIIntakeIntent.title, StartAIIntakeIntent.description),
        ("StartDraftCaptureIntent", StartDraftCaptureIntent.title, StartDraftCaptureIntent.description),
    ]

    @Test("No intent title or description contains the word Apple (ITMS-90626)")
    func noAppleInIntentMetadata() {
        for (name, title, description) in Self.metadata {
            let titleText = String(localized: title)
            #expect(!titleText.localizedStandardContains("apple"), "\(name) title: \(titleText)")

            if let description {
                let descriptionText = String(localized: description.descriptionText)
                #expect(!descriptionText.localizedStandardContains("apple"), "\(name) description: \(descriptionText)")
            }
        }
    }
}
