import SwiftUI

/// A prominent banner recommending which payment card to use
/// based on the user's current geographic location.
///
/// Displayed at the top of the Ledger when a recommendation is available.
/// Designed to prevent FX waste by surfacing the lowest-fee option.
struct ActiveCardBanner: View {

    let accountName: String
    let countryCode: String

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            icon

            recommendation

            Spacer()
        }
        .padding(SpacingTokens.small)
        .background(ColorTokens.brandPrimary.opacity(0.08))
        .clipShape(.rect(cornerRadius: SpacingTokens.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active card recommendation: Use \(accountName) in \(countryCode)")
    }
}

// MARK: - Private Helpers

private extension ActiveCardBanner {

    var icon: some View {
        Image(systemName: "creditcard.fill")
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .accessibilityHidden(true)
    }

    var recommendation: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text("Use \(accountName)")
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(ColorTokens.brandPrimary)

            Text("Best card for \(String.flagEmoji(for: countryCode)) \(countryCode) — lowest FX fees")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

}

#Preview {
    ActiveCardBanner(accountName: "Chase Freedom Rise", countryCode: "US")
        .padding()
}
