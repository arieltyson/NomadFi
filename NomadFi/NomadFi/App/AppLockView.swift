// AppLockView.swift
// NomadFi
//
// Full-screen lock overlay requiring authentication before the user
// can access financial data.

import LocalAuthentication
import SwiftUI

/// A full-screen lock overlay displayed when the app requires authentication.
///
/// One symbol, one line and one button. The system's own Face ID and
/// passcode prompts carry the explanation, so this screen does not
/// repeat it — and does not show its own progress while one of them
/// is on screen.
///
/// The background is solid rather than a material: a blur would still
/// leave the shape of balances visible behind the lock.
struct AppLockView: View {

    @Environment(AppLockManager.self) private var appLockManager

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(TypographyTokens.amountLarge)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)

            Text("NomadFi Locked")
                .font(TypographyTokens.amountMedium)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Spacer()

            NomadFiActionButton(
                title: unlockTitle,
                systemImage: biometricIcon,
                style: .primary,
                controlSize: .large,
                action: {
                    Task { await appLockManager.authenticate() }
                }
            )
            .disabled(appLockManager.isAuthenticating)
            .accessibilityIdentifier("appLock.unlockButton")
        }
        .padding(SpacingTokens.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.surfacePrimary)
        .task {
            guard appLockManager.isLocked else { return }
            await appLockManager.authenticate()
        }
    }

    private var unlockTitle: String {
        switch appLockManager.biometricType {
        case .faceID: "Unlock with Face ID"
        case .touchID: "Unlock with Touch ID"
        case .opticID: "Unlock with Optic ID"
        default: "Unlock with Passcode"
        }
    }

    private var biometricIcon: String {
        switch appLockManager.biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.open"
        }
    }
}
