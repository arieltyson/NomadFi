import LocalAuthentication
import Testing

@testable import NomadFi

@MainActor
struct AppLockManagerTests {

    @Test("Initial protected activation only locks once until the app truly backgrounds again")
    func initialProtectedActivationOnlyLocksOnce() async {
        let manager = AppLockManager(
            isAppLockEnabled: true,
            lockTimeout: .immediate,
            persistChanges: false,
            biometricStateProvider: {
                .init(isAvailable: true, type: .faceID)
            },
            authenticationEvaluator: {
                true
            }
        )

        manager.sceneDidBecomeActive()
        #expect(manager.isLocked)

        manager.isLocked = false
        manager.sceneDidBecomeActive()

        #expect(manager.isLocked == false)
    }

    @Test("Background lock state is consumed by the next active transition")
    func backgroundTimestampIsConsumedOnForeground() async {
        var currentDate = Date(timeIntervalSinceReferenceDate: 1_000)

        let manager = AppLockManager(
            isAppLockEnabled: true,
            lockTimeout: .immediate,
            persistChanges: false,
            now: { currentDate },
            biometricStateProvider: {
                .init(isAvailable: true, type: .faceID)
            },
            authenticationEvaluator: {
                true
            }
        )

        manager.sceneDidBecomeActive()
        manager.isLocked = false

        manager.sceneDidEnterBackground()
        currentDate = currentDate.addingTimeInterval(5)

        manager.sceneDidBecomeActive()
        #expect(manager.isLocked)

        manager.isLocked = false
        manager.sceneDidBecomeActive()

        #expect(manager.isLocked == false)
    }

    @Test("Disabling app lock clears the active lock state")
    func disablingAppLockClearsLockState() async {
        let manager = AppLockManager(
            isAppLockEnabled: true,
            lockTimeout: .immediate,
            persistChanges: false,
            biometricStateProvider: {
                .init(isAvailable: false, type: .none)
            },
            authenticationEvaluator: {
                true
            }
        )

        manager.sceneDidBecomeActive()
        #expect(manager.isLocked)

        manager.isAppLockEnabled = false

        #expect(manager.isLocked == false)
    }
}
