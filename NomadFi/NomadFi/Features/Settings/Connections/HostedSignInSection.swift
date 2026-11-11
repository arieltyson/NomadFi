// HostedSignInSection.swift
// NomadFi
//
// Consent and Sign in with Apple, before any bank is connected.

import AuthenticationServices
import SwiftUI

/// Asks once, plainly, before bank data is stored on NomadFi's server,
/// then signs in with Apple.
struct HostedSignInSection: View {

    let banking: HostedBankingController
    @Binding var hasConsented: Bool

    /// Grows with Dynamic Type from the HIG's minimum tap target.
    @ScaledMetric(relativeTo: .body) private var buttonHeight = SizeTokens.minimumTapTarget

    var body: some View {
        Section {
            Toggle("Sync bank data through NomadFi's server", isOn: $hasConsented)
            SignInWithAppleButton(.signIn) { request in
                request.nonce = banking.challenge?.nonce
                request.requestedScopes = []
            } onCompletion: { result in
                Task { await banking.completeAppleSignIn(result) }
            }
            .frame(height: buttonHeight)
            .disabled(!hasConsented || banking.challenge == nil || banking.isWorking || banking.privacyPolicyURL == nil)
        } footer: {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text("Your balances and transactions are kept on NomadFi's server so they stay current while your iPhone is closed. Plaid handles your bank sign-in.")
                HostedDataFooter(
                    region: banking.hostingRegion,
                    backupRetentionDays: banking.backupRetentionDays,
                    privacyPolicyURL: banking.privacyPolicyURL
                )
            }
        }
    }
}
