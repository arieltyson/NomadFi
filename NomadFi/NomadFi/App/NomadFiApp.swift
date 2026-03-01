import SwiftData
import SwiftUI
import TipKit

@main
struct NomadFiApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingSplash = true
    @State private var isBlurred = false
    @State private var appLockManager = AppLockManager()
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

                // Privacy blur for App Switcher — always active when backgrounded
                if isBlurred {
                    Rectangle().fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(2)
                }

                // Biometric lock overlay — blocks content until authenticated
                if appLockManager.isLocked && hasCompletedOnboarding {
                    AppLockView(appLockManager: appLockManager)
                        .zIndex(3)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    withAnimation(AnimationTokens.snappy) {
                        isBlurred = false
                    }
                    appLockManager.willEnterForeground()
                case .inactive, .background:
                    isBlurred = true
                    appLockManager.didEnterBackground()
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
