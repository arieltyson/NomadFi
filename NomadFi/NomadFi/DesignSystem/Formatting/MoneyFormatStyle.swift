// MoneyFormatStyle.swift
// NomadFi
//
// The one way NomadFi writes an amount of money.

import Foundation

/// Formats money as the currency's plain symbol, the amount, a space,
/// and its ISO code: `$3,250.75 CAD`, `$45,000.00 TTD`, `-$125.00 USD`.
///
/// `.currency(code:)` alone is right for a single-currency app but
/// wrong for one that holds several. It adapts to the device region,
/// so the same screen read "$3,250.75" for Canadian dollars,
/// "US$125.00" for US dollars and "TTD 45,000.00" for Trinidad and
/// Tobago dollars. Here every amount has a symbol and every amount
/// names its currency, in the same place every time.
///
/// Grouping, decimals and sign still follow the person's locale. For
/// VoiceOver, use ``spokenAmount(_:code:)`` — it reads "3,250.75
/// Canadian dollars" rather than spelling out the code.
///
/// ```swift
/// Text(balance, format: .money(code: "CAD"))
/// amount.formatted(.money(code: "TTD").precision(.fractionLength(0)))
/// ```
struct MoneyFormatStyle: FormatStyle {

    let code: String
    var locale: Locale = .autoupdatingCurrent
    var precision: NumberFormatStyleConfiguration.Precision?
    var showsCode = true

    func format(_ value: Double) -> String {
        var style = FloatingPointFormatStyle<Double>.Currency(code: code, locale: locale)
            .presentation(.narrow)
        if let precision {
            style = style.precision(precision)
        }

        let amount = value.formatted(style)
        // A currency with no symbol in this locale already shows its
        // code; never write it twice.
        guard showsCode, !amount.localizedStandardContains(code) else { return amount }
        return "\(amount) \(code)"
    }

    func locale(_ locale: Locale) -> Self {
        var style = self
        style.locale = locale
        return style
    }

    /// The same style with explicit precision, e.g. whole units.
    func precision(_ precision: NumberFormatStyleConfiguration.Precision) -> Self {
        var style = self
        style.precision = precision
        return style
    }

    /// The symbol and amount alone, for a table or chart whose
    /// currency is already stated once in its header.
    func codeHidden() -> Self {
        var style = self
        style.showsCode = false
        return style
    }

    /// The amount as VoiceOver should say it: "3,250.75 Canadian dollars".
    static func spokenAmount(_ value: Double, code: String) -> String {
        value.formatted(.currency(code: code).presentation(.fullName))
    }
}

extension FormatStyle where Self == MoneyFormatStyle {

    /// NomadFi's money format: `$3,250.75 CAD`.
    static func money(code: String) -> MoneyFormatStyle {
        MoneyFormatStyle(code: code)
    }
}
