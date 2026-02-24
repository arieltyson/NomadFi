import Foundation
import SwiftData

@Model
final class ExchangeRate {
    var baseCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var targetCurrencyRawValue: String = CurrencyCode.cad.rawValue
    var rate: Double = 0
    var fetchedAt: Date = .now

    var baseCurrency: CurrencyCode? {
        CurrencyCode(rawValue: baseCurrencyRawValue)
    }

    var targetCurrency: CurrencyCode? {
        CurrencyCode(rawValue: targetCurrencyRawValue)
    }

    var pairDisplayName: String {
        "\(baseCurrencyRawValue) -> \(targetCurrencyRawValue)"
    }

    init(
        baseCurrency: CurrencyCode = .usd,
        targetCurrency: CurrencyCode = .cad,
        rate: Double = 0,
        fetchedAt: Date = .now
    ) {
        self.baseCurrencyRawValue = baseCurrency.rawValue
        self.targetCurrencyRawValue = targetCurrency.rawValue
        self.rate = rate
        self.fetchedAt = fetchedAt
    }
}
