import SwiftData
import SwiftUI

@main
struct NomadFiApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .modelContainer(for: [
            Currency.self,
            JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            ExchangeRate.self,
            TaxDocument.self,
            Subscription.self,
            Budget.self,
        ])
    }
}
