// AppLockView.swift
// NomadFi
//
// Full-screen lock overlay requiring biometric authentication
// before the user can access financial data.

import LocalAuthentication
import SwiftUI

/// A full-screen lock overlay displayed when the app requires authentication.
///
/// Shows the NomadFi branding with an unlock button that triggers
/// Face ID, Touch ID, or device passcode authentication.
/// Blocks all interaction with the underlying content.
struct AppLockView: View {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(AppLockManager.self) private var appLockManager

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color(.systemBackground)
                    .ignoresSafeArea()
            } else {
                Rectangle().fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }

            VStack(spacing: SpacingTokens.large) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(TypographyTokens.amountMedium)
                    .foregroundStyle(ColorTokens.brandPrimary)

                Text("NomadFi is Locked")
                    .font(TypographyTokens.amountMedium)
                    .bold()

                Text("Authenticate to access your financial data.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if appLockManager.isAuthenticating {
                    ProgressView()
                        .controlSize(.regular)
                }

                Spacer()

                NomadFiActionButton(
                    title: appLockManager.isAuthenticating ? "Authenticating..." : "Unlock NomadFi",
                    systemImage: biometricIcon,
                    style: .primary,
                    controlSize: .large,
                    accessibilityHint: "Authenticates with \(biometricAccessLabel) or device passcode.",
                    action: {
                        Task { await appLockManager.authenticate() }
                    }
                )
                .disabled(appLockManager.isAuthenticating)
                .accessibilityIdentifier("appLock.unlockButton")
            }
            .padding(SpacingTokens.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NomadFi is locked. Authenticate to access your financial data.")
        .task {
            guard appLockManager.isLocked else { return }
            await appLockManager.authenticate()
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

    private var biometricAccessLabel: String {
        switch appLockManager.biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "biometrics"
        }
    }
}
