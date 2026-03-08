import SwiftUI

/// A prominent banner recommending which payment card to use
/// based on the user's current geographic location.
///
/// Displayed at the top of the Ledger when a recommendation is available.
/// Designed to prevent FX waste by surfacing the lowest-fee option.
struct ActiveCardBanner: View {

    let accountName: String
    let countryCode: String
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
        .accessibilityLabel("Active card recommendation: Use \(accountName) in \(countryCode)")
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
            Text("Use \(accountName)")
                .font(TypographyTokens.sectionHeader)
                .foregroundStyle(ColorTokens.actionTint)

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
