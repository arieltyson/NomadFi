// CurrencyText.swift
// NomadFi
//
// A reusable view for displaying formatted currency amounts
// with proper locale-aware formatting and Dynamic Type support.

import SwiftUI

/// Displays an amount in NomadFi's money format — `$3,250.75 CAD`.
///
/// Uses ``MoneyFormatStyle`` so every amount carries a symbol and its
/// currency code, and VoiceOver hears "3,250.75 Canadian dollars".
/// Supports the numeric text content transition for animated value changes.
///
/// ```swift
/// CurrencyText(amount: 4125.00, currencyCode: .usd)
/// CurrencyText(amount: 45000.00, currencyCode: .ttd, font: .largeTitle)
/// ```
struct CurrencyText: View {

    let amount: Double
    let currencyCode: CurrencyCode
    var font: Font = TypographyTokens.amountSmall
    var showSign: Bool = false

    var body: some View {
        Text(
            amount,
            format: .money(code: currencyCode.rawValue)
        )
        .font(font)
        .contentTransition(.numericText())
        .accessibilityLabel(accessibilityDescription)
    }

    /// The amount as VoiceOver says it: "3,250.75 Canadian dollars".
    private var accessibilityDescription: String {
        MoneyFormatStyle.spokenAmount(amount, code: currencyCode.rawValue)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: SpacingTokens.medium) {
        CurrencyText(amount: 67_215.75, currencyCode: .ttd, font: .largeTitle)
        CurrencyText(amount: 4_125.00, currencyCode: .usd, font: .title2)
        CurrencyText(amount: 8_750.25, currencyCode: .cad)
        CurrencyText(amount: -3.20, currencyCode: .usd)
    }
    .padding()
}
