import Foundation
import SwiftData

@Model
final class Account {
    var name: String = ""
    var institutionName: String = ""
    var accountTypeRawValue: String = AccountType.checking.rawValue
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var balance: Double = 0
    var jurisdiction: String = ""
    var isFinanceKitLinked: Bool = false
    var foreignTransactionFeePercent: Double = 0
    var createdAt: Date = .now
    var lastUpdatedAt: Date = .now

    @Relationship(inverse: \JurisdictionProfile.accounts)
    var jurisdictionProfile: JurisdictionProfile?

    @Relationship(inverse: \Transaction.account)
    var transactions: [Transaction]?

    @Relationship(inverse: \Subscription.account)
    var subscriptions: [Subscription]?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var accountType: AccountType? {
        AccountType(rawValue: accountTypeRawValue)
    }

    init(
        name: String = "",
        institutionName: String = "",
        accountType: AccountType = .checking,
        currencyCode: CurrencyCode = .usd,
        balance: Double = 0,
        jurisdiction: String = "",
        isFinanceKitLinked: Bool = false,
        foreignTransactionFeePercent: Double = 0,
        createdAt: Date = .now,
        lastUpdatedAt: Date = .now,
        jurisdictionProfile: JurisdictionProfile? = nil,
        transactions: [Transaction]? = nil,
        subscriptions: [Subscription]? = nil
    ) {
        self.name = name
        self.institutionName = institutionName
        self.accountTypeRawValue = accountType.rawValue
        self.currencyCodeRawValue = currencyCode.rawValue
        self.balance = balance
        self.jurisdiction = jurisdiction
        self.isFinanceKitLinked = isFinanceKitLinked
        self.foreignTransactionFeePercent = foreignTransactionFeePercent
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.jurisdictionProfile = jurisdictionProfile
        self.transactions = transactions
        self.subscriptions = subscriptions
    }
}
