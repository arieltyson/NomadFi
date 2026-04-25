import SwiftData
import SwiftUI
import TipKit

@main
struct NomadFiApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingSplash: Bool
    @State private var isBlurred = false
    @State private var appLockManager = AppLockManager()
    @State private var plaidLinkCoordinator = PlaidLinkCoordinator()
#if DEBUG
    /// Developer-only Plaid validation recorder. Lives at app root
    /// so the dev harness and the Financial Connections page write
    /// into the same session instance across navigation.
    @State private var plaidValidationRecorder = PlaidValidationRecorder()
#endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let uiTestConfig: UITestLaunchConfiguration

    init() {
        let config = UITestLaunchConfiguration()
        uiTestConfig = config

        if config.resetAppState, let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        if let hasCompletedOnboarding = config.hasCompletedOnboarding {
            UserDefaults.standard.set(
                hasCompletedOnboarding,
                forKey: "hasCompletedOnboarding"
            )
        }

        _isShowingSplash = State(initialValue: !config.disableSplash)

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
                if appLockManager.isLocked
                    && hasCompletedOnboarding
                    && !uiTestConfig.disableAppLock
                {
                    AppLockView()
                        .zIndex(3)
                }
            }
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                switch newPhase {
                case .active:
                    if reduceMotion || uiTestConfig.forceReduceMotion {
                        isBlurred = false
                    } else {
                        withAnimation(AnimationTokens.snappy) {
                            isBlurred = false
                        }
                    }

                    if !uiTestConfig.disableAppLock {
                        appLockManager.sceneDidBecomeActive()
                    }
                case .inactive:
                    isBlurred = true
                case .background:
                    isBlurred = true
                    if !uiTestConfig.disableAppLock {
                        appLockManager.sceneDidEnterBackground()
                    }
                @unknown default:
                    break
                }
            }
            .onOpenURL { url in
                // Plaid OAuth universal links return through the
                // `applinks:arieltyson.github.io` associated domain.
                // Forward them straight to the pending Link session;
                // anything the coordinator does not consume is
                // ignored so NomadFi never tries to reinterpret
                // an unrelated universal link.
                let handled = plaidLinkCoordinator.handle(universalLink: url)
#if DEBUG
                if handled {
                    plaidValidationRecorder.recordUniversalLinkObserved(
                        host: url.host()
                    )
                }
#else
                _ = handled
#endif
            }
            .environment(appLockManager)
            .environment(\.plaidLinkCoordinator, plaidLinkCoordinator)
#if DEBUG
            .environment(\.plaidValidationRecorder, plaidValidationRecorder)
#endif
            .tint(ColorTokens.actionTint)
        }
        // Single chokepoint: every `@Model` type is registered
        // through `NomadFiSchemaV1` and migrated by
        // `NomadFiMigrationPlan`. Future schema changes must add
        // a new versioned schema + migration stage rather than
        // appending to a list — that's what stops a quiet local-
        // store reset from happening on the next install.
        .modelContainer(NomadFiModelContainerFactory.makeProduction())
    }
}

private struct UITestLaunchConfiguration {

    let resetAppState: Bool
    let disableSplash: Bool
    let disableAppLock: Bool
    let forceReduceMotion: Bool
    let hasCompletedOnboarding: Bool?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let isUITesting = Self.boolValue(
            for: "UI_TEST_MODE",
            in: environment
        )

        if isUITesting {
            resetAppState = Self.boolValue(
                for: "UI_TEST_RESET_STATE",
                in: environment
            )
            disableSplash = Self.boolValue(
                for: "UI_TEST_DISABLE_SPLASH",
                in: environment
            )
            disableAppLock = Self.boolValue(
                for: "UI_TEST_DISABLE_APP_LOCK",
                in: environment
            )
            forceReduceMotion = Self.boolValue(
                for: "UI_TEST_FORCE_REDUCE_MOTION",
                in: environment
            )

            if let value = environment["UI_TEST_HAS_COMPLETED_ONBOARDING"] {
                hasCompletedOnboarding = Self.boolValue(from: value)
            } else {
                hasCompletedOnboarding = nil
            }
        } else {
            resetAppState = false
            disableSplash = false
            disableAppLock = false
            forceReduceMotion = false
            hasCompletedOnboarding = nil
        }
    }

    private static func boolValue(
        for key: String,
        in environment: [String: String]
    ) -> Bool {
        guard let value = environment[key] else { return false }
        return boolValue(from: value)
    }

    private static func boolValue(from value: String) -> Bool {
        switch value.lowercased() {
        case "1", "true", "yes", "y":
            return true
        default:
            return false
        }
    }
}
