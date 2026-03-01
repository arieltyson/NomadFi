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

    let appLockManager: AppLockManager

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.brandPrimary)

                Text("NomadFi is Locked")
                    .font(TypographyTokens.amountMedium)
                    .bold()

                Text("Authenticate to access your financial data.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button("Unlock NomadFi", systemImage: biometricIcon) {
                    Task {
                        await appLockManager.authenticate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(SpacingTokens.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NomadFi is locked. Authenticate to access your financial data.")
        .task {
            // Auto-trigger authentication on appearance
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
}
