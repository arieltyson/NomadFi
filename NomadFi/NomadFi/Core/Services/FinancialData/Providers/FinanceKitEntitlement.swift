// FinanceKitEntitlement.swift
// NomadFi
//
// Build-time + runtime gate that stops the FinanceKit adapter from
// entering `FinanceStore` symbols on a device that does not carry
// `com.apple.developer.financekit`. Required because every
// `FinanceStore` entry point — including the documented
// `isDataAvailable(.financialData)` probe — triggers an uncatchable
// "Process is not entitled" runtime abort when the entitlement is
// absent. Swift's `do { try … } catch` can't intercept that, so the
// only safe option is to never issue the call.
//
// ## Why a compilation condition
//
// Apple's preferred iOS shape for reading one's own entitlements at
// runtime (`SecTaskCopyValueForEntitlement`) lives in `SecTask.h`,
// which is not part of the public Swift `Security` module on iOS.
// Pulling it in via bridging headers is fragile and treats an SPI
// as if it were API. The cleaner, documented pattern is a
// compile-time flag that is flipped in lockstep with adding the
// entitlement to `NomadFi/NomadFi.entitlements`:
//
// 1. Apple approves the managed `com.apple.developer.financekit`
//    capability for `com.arieljtyson.NomadFi`.
// 2. Add the entitlement key to `NomadFi.entitlements`.
// 3. In the NomadFi target's build settings, add
//    `NOMADFI_FINANCEKIT_ENABLED` to
//    `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.
// 4. Rebuild + verify on a real device with a FinanceKit-eligible
//    account.
//
// Until step 3, the adapter treats FinanceKit as
// `.entitlementNotProvisioned` — the same state the app already
// surfaces honestly in the Settings row.
//
// References:
// - Apple FinanceKit onboarding:
//   https://developer.apple.com/financekit/
// - Managed capabilities overview:
//   https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app

import Foundation

enum FinanceKitEntitlement {

    /// Managed entitlement key Apple grants per approved bundle ID.
    /// Exposed for documentation / diagnostics; not used for the
    /// gate check itself (the gate is compile-time).
    static let entitlementKey = "com.apple.developer.financekit"

    /// Value that must appear inside the entitlement's string array
    /// to grant read access to on-device accounts, balances, and
    /// transactions.
    static let financialDataPermission = "financial-data"

    /// `true` when the app was built with the
    /// `NOMADFI_FINANCEKIT_ENABLED` compilation condition set AND a
    /// test override has not said otherwise. Default is `false` so
    /// any build without the entitlement paired to the flag stays
    /// safe on a real device.
    static var isProvisioned: Bool {
        #if DEBUG
        if let override = testOverride { return override }
        #endif
        return compileTimeValue
    }

    #if DEBUG
    /// Test-only override. Leave `nil` for the real compile-time
    /// behaviour; assign `true` or `false` in a test body (and
    /// restore to `nil` in a `defer`) to exercise either branch.
    nonisolated(unsafe) static var testOverride: Bool?
    #endif

    // MARK: - Internal

    private static let compileTimeValue: Bool = {
        #if NOMADFI_FINANCEKIT_ENABLED
        return true
        #else
        return false
        #endif
    }()
}
