import Foundation
import SwiftData

@Model
final class JurisdictionProfile {
    var countryCode: String = ""
    var countryName: String = ""
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var isHome: Bool = false
    var displayOrder: Int = 0
    var createdAt: Date = .now

    @Relationship(inverse: \Account.jurisdictionProfile)
    var accounts: [Account]?

    @Relationship(inverse: \Budget.jurisdictionProfile)
    var budgets: [Budget]?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    init(
        countryCode: String = "",
        countryName: String = "",
        currencyCode: CurrencyCode = .usd,
        isHome: Bool = false,
        displayOrder: Int = 0,
        createdAt: Date = .now,
        accounts: [Account]? = nil,
        budgets: [Budget]? = nil
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.currencyCodeRawValue = currencyCode.rawValue
        self.isHome = isHome
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.accounts = accounts
        self.budgets = budgets
    }
}
