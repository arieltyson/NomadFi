// AppLockManager.swift
// NomadFi
//
// Manages biometric authentication (Face ID / Touch ID) for app lock.
// Persists lock preferences securely in the Keychain.

import LocalAuthentication
import OSLog

/// Manages biometric app lock using Face ID or Touch ID.
///
/// Coordinates `LAContext` authentication with Keychain-persisted preferences.
/// When enabled, the app requires biometric or device passcode verification
/// after returning from the background.
///
/// Lock timeout options:
/// - `.immediate`: Lock as soon as the app enters background
/// - `.oneMinute`: Lock after 1 minute in background
/// - `.fiveMinutes`: Lock after 5 minutes in background
@MainActor
@Observable
final class AppLockManager {

    struct BiometricState {
        let isAvailable: Bool
        let type: LABiometryType
    }

    // MARK: - State

    /// Whether the app is currently locked and requires authentication.
    var isLocked = false

    /// Whether an authentication request is currently in flight.
    var isAuthenticating = false

    /// Whether biometric authentication is available on this device.
    var isBiometricAvailable = false

    /// The type of biometric available (Face ID, Touch ID, or none).
    var biometricType: LABiometryType = .none

    /// Whether the user has enabled the app lock feature.
    var isAppLockEnabled: Bool {
        didSet {
            persistIfNeeded(isAppLockEnabled, forKey: .appLockEnabled)

            if !isAppLockEnabled {
                isLocked = false
                backgroundedAt = nil
            }
        }
    }

    /// The selected lock timeout duration.
    var lockTimeout: LockTimeout {
        didSet {
            persistIfNeeded(lockTimeout.rawValue, forKey: .appLockTimeout)
        }
    }

    // MARK: - Private

    /// Timestamp when the app last entered the background.
    @ObservationIgnored
    private var backgroundedAt: Date?

    @ObservationIgnored
    private var hasCompletedInitialActivation = false

    @ObservationIgnored
    private let persistChanges: Bool

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private let biometricStateProvider: () -> BiometricState

    @ObservationIgnored
    private let authenticationEvaluator: () async throws -> Bool

    nonisolated private static let logger = Logger(subsystem: "com.nomadfi.app", category: "AppLock")

    // MARK: - Initialization

    init(
        isAppLockEnabled: Bool = KeychainService.loadBool(forKey: .appLockEnabled),
        lockTimeout: LockTimeout? = nil,
        persistChanges: Bool = true,
        now: @escaping () -> Date = { .now },
        biometricStateProvider: (() -> BiometricState)? = nil,
        authenticationEvaluator: (() async throws -> Bool)? = nil
    ) {
        self.persistChanges = persistChanges
        self.now = now
        self.biometricStateProvider = biometricStateProvider ?? Self.liveBiometricState
        self.authenticationEvaluator = authenticationEvaluator ?? Self.liveAuthenticate
        self.isAppLockEnabled = isAppLockEnabled
        self.lockTimeout = lockTimeout ?? Self.loadStoredLockTimeout()

        refreshBiometricAvailability()
    }

    // MARK: - Biometric Check

    /// Checks whether biometric authentication is available on this device.
    func refreshBiometricAvailability() {
        let biometricState = biometricStateProvider()
        isBiometricAvailable = biometricState.isAvailable
        biometricType = biometricState.type

        if biometricState.isAvailable == false, biometricType != .none {
            Self.logger.info("Biometric authentication is currently unavailable for configured biometry type")
        }
    }

    // MARK: - Authentication

    /// Attempts to authenticate the user via biometrics or device passcode.
    ///
    /// Uses `.deviceOwnerAuthentication` so the system can offer the
    /// current best authentication method, including passcode fallback.
    /// On success, sets `isLocked = false` to reveal the app content.
    func authenticate() async {
        guard isAppLockEnabled else {
            isLocked = false
            return
        }

        guard !isAuthenticating else { return }

        isAuthenticating = true
        defer { isAuthenticating = false }

        refreshBiometricAvailability()

        do {
            let success = try await authenticationEvaluator()

            if success {
                isLocked = false
                backgroundedAt = nil
                Self.logger.info("App unlocked via biometric/passcode")
            }
        } catch {
            // Authentication failed or was cancelled — stay locked
            Self.logger.info("Authentication failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Scene Phase Handling

    /// Called when the app enters the background.
    func sceneDidEnterBackground() {
        guard isAppLockEnabled else {
            backgroundedAt = nil
            return
        }

        guard !isAuthenticating else { return }

        backgroundedAt = now()
    }

    /// Called when the app becomes active.
    ///
    /// Locks the app if the elapsed background time exceeds the timeout and
    /// performs the one-time initial lock check when protection is enabled.
    func sceneDidBecomeActive() {
        refreshBiometricAvailability()

        guard isAppLockEnabled else {
            isLocked = false
            backgroundedAt = nil
            hasCompletedInitialActivation = true
            return
        }

        guard !isAuthenticating else { return }

        guard let backgroundedAt else {
            if !hasCompletedInitialActivation {
                isLocked = true
                Self.logger.info("App locked on initial protected activation")
            }

            hasCompletedInitialActivation = true
            return
        }

        self.backgroundedAt = nil

        let elapsed = now().timeIntervalSince(backgroundedAt)
        if elapsed >= lockTimeout.seconds {
            isLocked = true
            Self.logger.info("App locked after \(elapsed, privacy: .public)s in background")
        }

        hasCompletedInitialActivation = true
    }

    // MARK: - Helpers

    private func persistIfNeeded(_ value: Bool, forKey key: KeychainService.Key) {
        guard persistChanges else { return }
        KeychainService.save(value, forKey: key)
    }

    private func persistIfNeeded(_ value: String, forKey key: KeychainService.Key) {
        guard persistChanges else { return }
        KeychainService.save(value, forKey: key)
    }

    nonisolated private static func loadStoredLockTimeout() -> LockTimeout {
        let timeoutRaw = KeychainService.loadString(forKey: .appLockTimeout) ?? LockTimeout.immediate.rawValue
        return LockTimeout(rawValue: timeoutRaw) ?? .immediate
    }

    nonisolated private static func liveBiometricState() -> BiometricState {
        let context = LAContext()
        var error: NSError?
        let isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        if let error {
            Self.logger.info("Biometrics unavailable: \(error.localizedDescription, privacy: .public)")
        }

        return BiometricState(
            isAvailable: isAvailable,
            type: context.biometryType
        )
    }

    nonisolated private static func liveAuthenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        // The system already titles the prompt "Enter iPhone Passcode
        // for NomadFi", so the reason says only why — never the app's
        // name or the action again.
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Keeps your financial data private."
        )
    }
}

// MARK: - Lock Timeout

/// Configurable timeout before the app lock engages.
enum LockTimeout: String, CaseIterable, Identifiable, Sendable {
    case immediate = "immediate"
    case oneMinute = "1min"
    case fiveMinutes = "5min"

    var id: String { rawValue }

    /// The number of seconds before locking.
    var seconds: TimeInterval {
        switch self {
        case .immediate: 0
        case .oneMinute: 60
        case .fiveMinutes: 300
        }
    }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .immediate: "Immediately"
        case .oneMinute: "After 1 minute"
        case .fiveMinutes: "After 5 minutes"
        }
    }
}
