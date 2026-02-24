import Foundation
import SwiftData

@Model
final class Budget {
    var name: String = ""
    var limitAmount: Double = 0
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var spentAmount: Double = 0
    var periodRawValue: String = BudgetPeriod.monthly.rawValue
    var jurisdiction: String = ""
    var periodStartDate: Date = Date.now
    var alertsEnabled: Bool = true
    var createdAt: Date = Date.now

    var jurisdictionProfile: JurisdictionProfile?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var period: BudgetPeriod? {
        BudgetPeriod(rawValue: periodRawValue)
    }

    var remainingAmount: Double {
        max(limitAmount - spentAmount, 0)
    }

    var spentFraction: Double {
        guard limitAmount > 0 else { return 0 }
        return spentAmount / limitAmount
    }

    var isOverBudget: Bool {
        spentAmount > limitAmount
    }

    init(
        name: String = "",
        limitAmount: Double = 0,
        currencyCode: CurrencyCode = .usd,
        spentAmount: Double = 0,
        period: BudgetPeriod = .monthly,
        jurisdiction: String = "",
        periodStartDate: Date = .now,
        alertsEnabled: Bool = true,
        createdAt: Date = .now,
        jurisdictionProfile: JurisdictionProfile? = nil
    ) {
        self.name = name
        self.limitAmount = limitAmount
        self.currencyCodeRawValue = currencyCode.rawValue
        self.spentAmount = spentAmount
        self.periodRawValue = period.rawValue
        self.jurisdiction = jurisdiction
        self.periodStartDate = periodStartDate
        self.alertsEnabled = alertsEnabled
        self.createdAt = createdAt
        self.jurisdictionProfile = jurisdictionProfile
    }
}
