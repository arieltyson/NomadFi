// HostedSignInSection.swift
// NomadFi
//
// Consent and Sign in with Apple, before any bank is connected.

import AuthenticationServices
import SwiftUI

/// Says plainly what Bank Connections stores, then signs in with Apple.
///
/// Signing in is the consent: the disclosure sits directly above the
/// button and the storage region, backups and privacy policy directly
/// below it, so tapping it is an informed choice. A separate toggle made
/// people turn something on before the button would respond, which read
/// as a button that was broken.
struct HostedSignInSection: View {

    let banking: HostedBankingController

    /// Grows with Dynamic Type from the HIG's minimum tap target.
    @ScaledMetric(relativeTo: .body) private var buttonHeight = SizeTokens.minimumTapTarget

    var body: some View {
        Section {
            Text("Your balances and transactions are kept on NomadFi's server, so they stay up to date while your iPhone is closed. Plaid handles your bank sign-in.")
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.continue) { request in
                request.nonce = banking.challenge?.nonce
                request.requestedScopes = []
            } onCompletion: { result in
                Task { await banking.completeAppleSignIn(result) }
            }
            .frame(height: buttonHeight)
            .disabled(banking.challenge == nil || banking.isWorking || banking.privacyPolicyURL == nil)
        } footer: {
            HostedDataFooter(
                region: banking.hostingRegion,
                backupRetentionDays: banking.backupRetentionDays,
                privacyPolicyURL: banking.privacyPolicyURL
            )
        }
    }
}
