import SwiftData
import SwiftUI
import TipKit

@main
struct NomadFiApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingSplash = true
    @State private var isBlurred = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        try? Tips.configure([
            .displayFrequency(.weekly)
        ])
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingFlowView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }

                if isShowingSplash {
                    SplashView(isActive: $isShowingSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if isBlurred {
                    Rectangle().fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(2)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    withAnimation(AnimationTokens.snappy) {
                        isBlurred = false
                    }
                case .inactive, .background:
                    isBlurred = true
                @unknown default:
                    break
                }
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
