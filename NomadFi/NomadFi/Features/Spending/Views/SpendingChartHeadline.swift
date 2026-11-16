import SwiftUI

/// The name and amount a Spending chart is showing: the whole, or the
/// slice the person is touching.
struct SpendingChartHeadline: View {

    let title: String
    let amount: Double
    let currency: CurrencyCode

    /// How far a large amount may shrink to stay on one line inside the
    /// wheel's hole before it is truncated.
    private static let minimumAmountScale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: SpacingTokens.xxSmall) {
            Text(title)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            CurrencyText(amount: amount, currencyCode: currency, font: TypographyTokens.sectionHeader)
                .lineLimit(1)
                .minimumScaleFactor(Self.minimumAmountScale)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
