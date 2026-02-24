import Foundation
import SwiftData

@Model
final class Currency {
    var codeRawValue: String = CurrencyCode.usd.rawValue
    var displayName: String = CurrencyCode.usd.displayName
    var symbol: String = CurrencyCode.usd.symbol

    var code: CurrencyCode? {
        CurrencyCode(rawValue: codeRawValue)
    }

    init(code: CurrencyCode = .usd) {
        self.codeRawValue = code.rawValue
        self.displayName = code.displayName
        self.symbol = code.symbol
    }
}
