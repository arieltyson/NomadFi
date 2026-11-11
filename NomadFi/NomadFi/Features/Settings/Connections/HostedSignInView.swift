// HostedSignInView.swift
// NomadFi
//
// The invitation to connect a bank, before signing in.

import AuthenticationServices
import SwiftUI

/// What Bank Connections shows before sign-in: one idea, three short
/// reasons, one button.
///
/// Continuing with Apple is the consent to keep bank data on NomadFi's
/// server, so the single line beneath the button says exactly that and
/// links the privacy policy. Where and how the data is stored lives in
/// the policy, not on this screen.
struct HostedSignInView: View {

    let banking: HostedBankingController

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xLarge) {
                HostedSignInHero()

                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    HostedSignInReason(
                        systemImage: "lock.shield.fill",
                        title: "Secured by Plaid",
                        detail: "You sign in with your bank through Plaid. NomadFi never sees your password."
                    )
                    HostedSignInReason(
                        systemImage: "arrow.triangle.2.circlepath",
                        title: "Always up to date",
                        detail: "New activity arrives on its own, even while NomadFi is closed."
                    )
                    HostedSignInReason(
                        systemImage: "hand.raised.fill",
                        title: "Yours to remove",
                        detail: "Disconnect a bank or delete everything whenever you like."
                    )
                }

                if let message = banking.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                #if DEBUG
                if let subject = banking.refusedAppleSubject {
                    HostedPilotAccessCard(subject: subject)
                }
                #endif
            }
            .padding(.horizontal, SpacingTokens.large)
            .padding(.vertical, SpacingTokens.xLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            HostedSignInAction(banking: banking)
                .padding(.horizontal, SpacingTokens.large)
                .padding(.bottom, SpacingTokens.medium)
        }
    }
}

/// The symbol, the title and the one-line promise.
private struct HostedSignInHero: View {

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "building.columns.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(ColorTokens.brandPrimary.gradient)
                .accessibilityHidden(true)

            Text("Connect Your Banks")
                .font(.title)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text("Every balance and transaction in one place, kept current for you.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

/// One reason: a symbol, a short title and a sentence.
private struct HostedSignInReason: View {

    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @ScaledMetric(relativeTo: .title3) private var symbolWidth = SpacingTokens.xLarge

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Continue with Apple, and the one line that makes it informed consent.
private struct HostedSignInAction: View {

    let banking: HostedBankingController

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var buttonHeight = SizeTokens.holdButtonHeight

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            SignInWithAppleButton(.continue) { request in
                request.nonce = banking.challenge?.nonce
                request.requestedScopes = []
            } onCompletion: { result in
                Task { await banking.completeAppleSignIn(result) }
            }
            // Apple's button in the style that contrasts with the screen.
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: buttonHeight)
            .clipShape(.capsule)
            .disabled(banking.challenge == nil || banking.isWorking || banking.privacyPolicyURL == nil)
            // Recreate the button when the scheme changes; its style is fixed at creation.
            .id(colorScheme)

            if let policy = banking.privacyPolicyURL {
                Text("Your bank data is kept on NomadFi's server. [Privacy Policy](\(policy.absoluteString))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#if DEBUG
/// Debug builds only: the Apple ID the server refused, to allow it.
private struct HostedPilotAccessCard: View {

    let subject: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Pilot access (Debug)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(subject)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
            ShareLink("Share Apple ID", item: subject)
        }
        .padding(SpacingTokens.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceSecondary, in: .rect(cornerRadius: RadiusTokens.card))
    }
}
#endif
