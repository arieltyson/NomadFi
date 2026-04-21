import SwiftUI

/// A prominent banner recommending which payment card to use
/// based on the user's current geographic location.
///
/// Displayed at the top of the Ledger when a recommendation is available.
/// Designed to prevent FX waste by surfacing the lowest-fee option.
struct ActiveCardBanner: View {

    let accountName: String
    let countryCode: String
    /// Confidence in the underlying foreign-transaction-fee data for the
    /// recommended account. When this is not verified, the banner phrases
    /// itself in terms of saved fee data rather than implying issuer
    /// verification.
    var feeConfidence: SourceConfidence? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let increasedContrast = colorSchemeContrast == .increased

        HStack(spacing: SpacingTokens.small) {
            icon

            recommendation

            Spacer()
        }
        .padding(SpacingTokens.small)
        .background {
            if reduceTransparency {
                ColorTokens.actionTint.opacity(increasedContrast ? 0.2 : 0.08)
            } else {
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(ColorTokens.actionTint.opacity(increasedContrast ? 0.14 : 0.05))
            }
        }
        .clipShape(.rect(cornerRadius: SpacingTokens.small))
        .overlay {
            if increasedContrast {
                RoundedRectangle(cornerRadius: SpacingTokens.small)
                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityNarrative)
    }
}

// MARK: - Private Helpers

private extension ActiveCardBanner {

    var icon: some View {
        Image(systemName: "creditcard.fill")
            .font(.title3)
            .foregroundStyle(ColorTokens.actionTint)
            .accessibilityHidden(true)
    }

    var recommendation: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(spacing: SpacingTokens.xxSmall) {
                StatusBadge(
                    label: "Recommended",
                    color: ColorTokens.actionTint,
                    systemImage: "checkmark.circle.fill"
                )

                if let feeConfidence {
                    StatusBadge(
                        label: feeConfidence.displayLabel,
                        color: feeConfidence.isVerified ? ColorTokens.positive : ColorTokens.warning,
                        systemImage: feeConfidence.isVerified ? "checkmark.seal" : "info.circle"
                    )
                }
            }

            Text("Use \(accountName)")
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(ColorTokens.actionTint)

            Text(subtitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    var subtitle: String {
        let prefix = "Best card for \(String.flagEmoji(for: countryCode)) \(countryCode)"
        guard let feeConfidence else {
            return "\(prefix) — lowest FX fees"
        }
        switch feeConfidence {
        case .verifiedPrimary, .verifiedSecondary:
            return "\(prefix) — lowest FX fees"
        case .unverified:
            // `SourceFreshness.effectiveConfidence` degrades stale verified
            // issuer data to `.unverified`, so this branch fires for both
            // "never verified" and "verified but stale" inputs.
            return "\(prefix) — needs re-verification with your issuer"
        case .userProvided, .indicative, .institutional, .peerReviewed:
            return "\(prefix) — based on saved fee data; verify with your issuer"
        }
    }

    var accessibilityNarrative: String {
        var narrative = "Active card recommendation: Use \(accountName) in \(countryCode)."
        if let feeConfidence {
            narrative += " Fee data confidence: \(feeConfidence.displayLabel)."
        }
        return narrative
    }
}

#Preview {
    VStack(spacing: SpacingTokens.medium) {
        ActiveCardBanner(
            accountName: "Chase Freedom Rise",
            countryCode: "US",
            feeConfidence: .userProvided
        )
        ActiveCardBanner(
            accountName: "CIBC Dividend Cash Back",
            countryCode: "CA",
            feeConfidence: .verifiedPrimary
        )
    }
    .padding()
}
