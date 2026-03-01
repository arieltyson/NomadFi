// ThreatModel.swift
// NomadFi
//
// Documents the threat model for NomadFi's security posture.
// This file serves as executable documentation — the security
// assertions are testable via the patterns documented here.

// swiftlint:disable file_length

/// NomadFi Threat Model
///
/// NomadFi handles real financial data for international students — a
/// population that is particularly vulnerable to financial exploitation.
/// This threat model identifies attack vectors and documents mitigations.
///
/// ## Threat Categories
///
/// ### 1. Device Theft
/// **Scenario:** An unlocked or recently-locked device is stolen.
/// **Mitigations:**
/// - App Lock with Face ID / Touch ID / device passcode (``AppLockManager``)
/// - Configurable lock timeout: immediate, 1 minute, 5 minutes
/// - App Switcher privacy blur on scene phase change (``NomadFiApp``)
/// - Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///   — not accessible from backups, not synced to iCloud Keychain
/// - Receipt images stored in app sandbox (not in shared photo library)
///
/// ### 2. Shoulder Surfing
/// **Scenario:** Someone views the user's screen over their shoulder.
/// **Mitigations:**
/// - App Switcher blur prevents casual observation of financial data
/// - Notification content uses generic text — no amounts, names, or
///   currency pairs visible on Lock Screen
/// - Dynamic Type support ensures users can increase text size for
///   closer viewing distance
///
/// ### 3. Malicious Wi-Fi (Man-in-the-Middle)
/// **Scenario:** Attacker intercepts network traffic on public Wi-Fi.
/// **Mitigations:**
/// - App Transport Security (ATS) enforces TLS 1.2+ with no exceptions
/// - Certificate validation via ``CertificatePinningDelegate`` using
///   `SecTrustEvaluateWithError` against the system trust store
/// - Exchange rate API requests contain zero PII (only currency codes)
/// - No authentication tokens transmitted over the network
/// - Ephemeral `URLSession` configuration — no responses cached to disk
///
/// ### 4. iCloud Compromise
/// **Scenario:** Attacker gains access to the user's iCloud account.
/// **Mitigations:**
/// - Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///   — excluded from iCloud Keychain and unencrypted backups
/// - SwiftData uses Apple's standard iCloud sync (if enabled) which
///   provides end-to-end encryption managed by Apple
/// - API tokens and biometric state are never stored in SwiftData
///   or UserDefaults — Keychain only
/// - Export archives are generated in temporary directories and cleaned
///   up after sharing
///
/// ### 5. Shared Device
/// **Scenario:** Multiple people use the same iPhone (family, roommates).
/// **Mitigations:**
/// - App Lock requires biometric authentication on each open
/// - Lock triggers on background with configurable timeout
/// - "Delete All My Data" in Settings for complete wipe before
///   transferring device (``DataGovernancePolicy/deleteAllUserData``)
/// - Spotlight entries are removed on data wipe
/// - Pending notifications are removed on data wipe
///
/// ### 6. Receipt Image Metadata Leakage
/// **Scenario:** Exported receipt images contain GPS coordinates or
///   device identifiers in EXIF metadata.
/// **Mitigations:**
/// - ``ImageMetadataStripper`` removes EXIF, GPS, TIFF, IPTC, and
///   Apple Maker metadata from all receipt images
/// - Stripping occurs at two points: on initial save to disk and
///   during export to `.zip` archive (defense in depth)
/// - Only orientation and color profile metadata is preserved
///
/// ### 7. Input Injection
/// **Scenario:** Malicious text entered in merchant names or notes
///   causes unintended behavior in storage, display, or export.
/// **Mitigations:**
/// - ``InputSanitizer`` strips control characters (U+0000-U+001F
///   except tab/newline/CR, U+007F-U+009F) from all text inputs
/// - Text length enforced: 200 characters for short text, 5,000
///   for long text
/// - Currency amounts validated: NaN, Infinity, negative-zero, and
///   values exceeding 10 billion are rejected
/// - Exchange rates validated: zero, negative, and rates exceeding
///   100,000 are rejected
/// - Vision OCR output is treated as untrusted input and sanitized
///   before storage
/// - SwiftData `#Predicate` queries use parameterized values
///
/// ### 8. Keyboard Autocomplete Leakage
/// **Scenario:** Financial data (account numbers, amounts) persists
///   in the system keyboard's autocomplete dictionary.
/// **Mitigations:**
/// - All financial input fields use `.textContentType(.none)` and
///   `.autocorrectionDisabled()` to prevent system caching
/// - Applied to: merchant names, amounts, converted amounts, notes,
///   account names, institution names, service names, balances
///
/// ### 9. Export Archive Manipulation
/// **Scenario:** The exported `.zip` tax report contains unexpected
///   files or allows directory traversal.
/// **Mitigations:**
/// - Export directory is created fresh in `temporaryDirectory` for
///   each export, with any previous export cleaned up first
/// - `NSFileCoordinator` with `.forUploading` creates the archive —
///   this is Apple's standard secure archiving mechanism
/// - File names are generated programmatically (no user input in
///   file paths) — format: `NomadFi_TaxReport_{CC}_{YYYY}.pdf`
/// - Receipt filenames use timestamps: `receipt_{timestamp}.jpg`
/// - Export directory is deleted after archive creation
///
/// ### 10. Logging / Diagnostics Leakage
/// **Scenario:** Financial data appears in system logs accessible
///   via Console.app or crash reports.
/// **Mitigations:**
/// - All `OSLog` string interpolations containing financial data use
///   `.private` redaction (merchant names, country codes, amounts,
///   service names, exchange rates)
/// - Numeric values that could identify amounts use `.private`
/// - Only operational metadata (counts, success/failure, timestamps)
///   is logged as `.public`
/// - No third-party crash reporting or analytics SDKs
///
/// ## Data Classification
///
/// | Data Type | Storage | Protection |
/// |---|---|---|
/// | Account names | SwiftData | App sandbox + optional iCloud E2E |
/// | Balances | SwiftData | App sandbox + optional iCloud E2E |
/// | Transactions | SwiftData | App sandbox + optional iCloud E2E |
/// | Receipt images | Documents/receipts/ | App sandbox, EXIF stripped |
/// | API tokens | Keychain | Hardware-backed, device-only |
/// | App lock state | Keychain | Hardware-backed, device-only |
/// | Exchange rates | SwiftData | App sandbox (non-sensitive) |
/// | Onboarding state | UserDefaults | App sandbox (non-sensitive) |
///
/// ## Trust Boundaries
///
/// ```
/// ┌─────────────────────────────────────┐
/// │          Device Hardware             │
/// │  ┌───────────────────────────────┐  │
/// │  │      App Sandbox              │  │
/// │  │  ┌─────────┐ ┌────────────┐  │  │
/// │  │  │SwiftData│ │ Documents/ │  │  │
/// │  │  │ models  │ │  receipts  │  │  │
/// │  │  └─────────┘ └────────────┘  │  │
/// │  │  ┌──────────────────────┐    │  │
/// │  │  │     Keychain         │    │  │
/// │  │  │ (hardware-backed)    │    │  │
/// │  │  └──────────────────────┘    │  │
/// │  └───────────────────────────────┘  │
/// │                                     │
/// │  ┌───────────────────────────────┐  │
/// │  │  Biometric Enclave (Secure)   │  │
/// │  └───────────────────────────────┘  │
/// └─────────────────────────────────────┘
///         │ HTTPS (TLS 1.2+)
///         ▼
/// ┌───────────────────┐
/// │ Exchange Rate API │ ← Only currency codes sent
/// │ (public, no auth) │ ← No PII, no tokens
/// └───────────────────┘
/// ```
enum ThreatModel {
    // This enum exists purely as documentation.
    // It serves as a compile-time reference that stays in sync
    // with the codebase through code review discipline.
}

// swiftlint:enable file_length
