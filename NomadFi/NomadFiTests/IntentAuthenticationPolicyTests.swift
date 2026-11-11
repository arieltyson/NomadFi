import AppIntents
import Testing
@testable import NomadFi

/// Siri and Shortcuts can run background intents from a locked iPhone.
/// Every one of NomadFi's touches financial data, so each must require
/// the device to be unlocked. Add new intents to `allIntents`.
struct IntentAuthenticationPolicyTests {

    private static let allIntents: [any AppIntent.Type] = [
        ActiveCardIntent.self, CaptureDecisionDraftIntent.self, CheckBudgetIntent.self,
        CheckNetWorthIntent.self, ContinueAmazonArrivalDecisionIntent.self, LogExpenseIntent.self,
        OpenAIIntakeIntent.self, OpenDecisionAssistantIntent.self, RecommendCardIntent.self,
        ReviewAmazonArrivalDecisionIntent.self, ReviewCreditTimingIntent.self, StartAIIntakeIntent.self,
        StartDraftCaptureIntent.self,
    ]

    @Test func everyBackgroundIntentRequiresAnUnlockedDevice() {
        let background = Self.allIntents.filter { $0.supportedModes == .background }
        #expect(background.count == 8)
        for intent in background {
            #expect(
                intent.authenticationPolicy == .requiresAuthentication,
                "\(intent) runs in the background without requiring an unlocked device"
            )
        }
    }
}
