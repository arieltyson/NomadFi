// CurrencyText.swift
// NomadFi
//
// A reusable view for displaying formatted currency amounts
// with proper locale-aware formatting and Dynamic Type support.

import SwiftUI

/// Displays a formatted currency amount with its currency code.
///
/// Uses `Decimal.FormatStyle.Currency` for locale-aware formatting.
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
            format: .currency(code: currencyCode.rawValue)
        )
        .font(font)
        .contentTransition(.numericText())
        .accessibilityLabel(accessibilityDescription)
    }

    /// A human-readable description for VoiceOver.
    private var accessibilityDescription: String {
        let formatted = amount.formatted(.currency(code: currencyCode.rawValue))
        return "\(formatted) \(currencyCode.displayName)"
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
