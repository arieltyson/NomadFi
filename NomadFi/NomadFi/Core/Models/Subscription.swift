import Foundation
import SwiftData

@Model
final class Subscription {
    var serviceName: String = ""
    var amount: Double = 0
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var frequencyRawValue: String = BillingFrequency.monthly.rawValue
    var nextRenewalDate: Date = .now
    var jurisdiction: String = ""
    var homeCurrencyEquivalent: Double = 0
    var cheapestAlternativeAmount: Double = 0
    var cheapestAlternativeCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var cheapestAlternativeJurisdiction: String = ""
    var hasNotifiedSavings: Bool = false
    var detectedAt: Date = .now

    @Relationship(inverse: \Account.subscriptions)
    var account: Account?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var frequency: BillingFrequency? {
        BillingFrequency(rawValue: frequencyRawValue)
    }

    var monthlySavings: Double {
        guard let frequency else { return 0 }
        guard homeCurrencyEquivalent > 0, cheapestAlternativeAmount > 0 else { return 0 }
        let yearlyCurrent = homeCurrencyEquivalent * frequency.annualizedMultiplier
        let yearlyAlternative = cheapestAlternativeAmount * frequency.annualizedMultiplier
        let annualDifference = yearlyCurrent - yearlyAlternative
        return max(annualDifference / 12, 0)
    }

    var annualSavings: Double {
        monthlySavings * 12
    }

    init(
        serviceName: String = "",
        amount: Double = 0,
        currencyCode: CurrencyCode = .usd,
        frequency: BillingFrequency = .monthly,
        nextRenewalDate: Date = .now,
        jurisdiction: String = "",
        homeCurrencyEquivalent: Double = 0,
        cheapestAlternativeAmount: Double = 0,
        cheapestAlternativeCurrency: CurrencyCode = .usd,
        cheapestAlternativeJurisdiction: String = "",
        hasNotifiedSavings: Bool = false,
        detectedAt: Date = .now,
        account: Account? = nil
    ) {
        self.serviceName = serviceName
        self.amount = amount
        self.currencyCodeRawValue = currencyCode.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.nextRenewalDate = nextRenewalDate
        self.jurisdiction = jurisdiction
        self.homeCurrencyEquivalent = homeCurrencyEquivalent
        self.cheapestAlternativeAmount = cheapestAlternativeAmount
        self.cheapestAlternativeCurrencyRawValue = cheapestAlternativeCurrency.rawValue
        self.cheapestAlternativeJurisdiction = cheapestAlternativeJurisdiction
        self.hasNotifiedSavings = hasNotifiedSavings
        self.detectedAt = detectedAt
        self.account = account
    }
}
