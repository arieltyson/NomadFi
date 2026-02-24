import Foundation
import SwiftData

@Model
final class Transaction {
    var merchantName: String = ""
    var originalAmount: Double = 0
    var originalCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var convertedAmount: Double = 0
    var homeCurrencyRawValue: String = CurrencyCode.usd.rawValue
    var appliedExchangeRate: Double = 0
    var midMarketRate: Double = 0
    var date: Date = Date.now
    var categoryRawValue: String = TransactionCategory.other.rawValue
    var jurisdiction: String = ""
    var notes: String = ""
    var isTaxDeductible: Bool = false
    var isFinanceKitImported: Bool = false
    var createdAt: Date = Date.now

    var account: Account?

    @Relationship(inverse: \TaxDocument.transaction)
    var taxDocument: TaxDocument?

    var originalCurrency: CurrencyCode? {
        CurrencyCode(rawValue: originalCurrencyRawValue)
    }

    var homeCurrency: CurrencyCode? {
        CurrencyCode(rawValue: homeCurrencyRawValue)
    }

    var category: TransactionCategory? {
        TransactionCategory(rawValue: categoryRawValue)
    }

    var fxMarkup: Double {
        guard midMarketRate > 0 else { return 0 }
        let fairConvertedAmount = originalAmount * midMarketRate
        return convertedAmount - fairConvertedAmount
    }

    init(
        merchantName: String = "",
        originalAmount: Double = 0,
        originalCurrency: CurrencyCode = .usd,
        convertedAmount: Double = 0,
        homeCurrency: CurrencyCode = .usd,
        appliedExchangeRate: Double = 0,
        midMarketRate: Double = 0,
        date: Date = .now,
        category: TransactionCategory = .other,
        jurisdiction: String = "",
        notes: String = "",
        isTaxDeductible: Bool = false,
        isFinanceKitImported: Bool = false,
        createdAt: Date = .now,
        account: Account? = nil,
        taxDocument: TaxDocument? = nil
    ) {
        self.merchantName = merchantName
        self.originalAmount = originalAmount
        self.originalCurrencyRawValue = originalCurrency.rawValue
        self.convertedAmount = convertedAmount
        self.homeCurrencyRawValue = homeCurrency.rawValue
        self.appliedExchangeRate = appliedExchangeRate
        self.midMarketRate = midMarketRate
        self.date = date
        self.categoryRawValue = category.rawValue
        self.jurisdiction = jurisdiction
        self.notes = notes
        self.isTaxDeductible = isTaxDeductible
        self.isFinanceKitImported = isFinanceKitImported
        self.createdAt = createdAt
        self.account = account
        self.taxDocument = taxDocument
    }
}
