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

    // MARK: - State

    /// Whether the app is currently locked and requires authentication.
    var isLocked = false

    /// Whether biometric authentication is available on this device.
    var isBiometricAvailable = false

    /// The type of biometric available (Face ID, Touch ID, or none).
    var biometricType: LABiometryType = .none

    /// Whether the user has enabled the app lock feature.
    var isAppLockEnabled: Bool {
        didSet {
            KeychainService.save(isAppLockEnabled, forKey: .appLockEnabled)
        }
    }

    /// The selected lock timeout duration.
    var lockTimeout: LockTimeout {
        didSet {
            KeychainService.save(lockTimeout.rawValue, forKey: .appLockTimeout)
        }
    }

    // MARK: - Private

    /// Timestamp when the app last entered the background.
    private var backgroundedAt: Date?

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "AppLock")

    // MARK: - Initialization

    init() {
        isAppLockEnabled = KeychainService.loadBool(forKey: .appLockEnabled)
        let timeoutRaw = KeychainService.loadString(forKey: .appLockTimeout) ?? LockTimeout.immediate.rawValue
        lockTimeout = LockTimeout(rawValue: timeoutRaw) ?? .immediate

        checkBiometricAvailability()
    }

    // MARK: - Biometric Check

    /// Checks whether biometric authentication is available on this device.
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        biometricType = context.biometryType

        if let error {
            Self.logger.info("Biometrics unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Authentication

    /// Attempts to authenticate the user via biometrics or device passcode.
    ///
    /// Falls back to device passcode if biometrics are unavailable or fail.
    /// On success, sets `isLocked = false` to reveal the app content.
    func authenticate() async {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        // Use deviceOwnerAuthentication to allow passcode fallback
        let policy: LAPolicy = isBiometricAvailable
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        do {
            let success = try await context.evaluatePolicy(
                policy,
                localizedReason: "Unlock NomadFi to access your financial data"
            )

            if success {
                isLocked = false
                Self.logger.info("App unlocked via biometric/passcode")
            }
        } catch {
            // Authentication failed or was cancelled — stay locked
            Self.logger.info("Authentication failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Scene Phase Handling

    /// Called when the app enters the background.
    func didEnterBackground() {
        backgroundedAt = .now
    }

    /// Called when the app returns to the foreground.
    ///
    /// Locks the app if the elapsed background time exceeds the timeout.
    func willEnterForeground() {
        guard isAppLockEnabled else { return }

        guard let backgroundedAt else {
            // First launch with lock enabled — require auth
            isLocked = true
            return
        }

        let elapsed = Date.now.timeIntervalSince(backgroundedAt)
        if elapsed >= lockTimeout.seconds {
            isLocked = true
            Self.logger.info("App locked after \(elapsed, privacy: .public)s in background")
        }
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
