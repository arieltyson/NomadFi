import Foundation
import SwiftData

@Model
final class TaxDocument {
    var merchantName: String = ""
    var amount: Double = 0
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue
    var documentDate: Date = .now
    var taxYear: Int = 0
    var jurisdiction: String = ""
    var taxCategoryRawValue: String = TaxCategory.other.rawValue
    var extractedText: String = ""
    var imageRelativePath: String = ""
    var scannedAt: Date = .now
    var isVerified: Bool = false

    @Relationship(inverse: \Transaction.taxDocument)
    var transaction: Transaction?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var taxCategory: TaxCategory? {
        TaxCategory(rawValue: taxCategoryRawValue)
    }

    var imageURL: URL? {
        guard !imageRelativePath.isEmpty else { return nil }
        return URL.documentsDirectory.appending(path: imageRelativePath)
    }

    init(
        merchantName: String = "",
        amount: Double = 0,
        currencyCode: CurrencyCode = .usd,
        documentDate: Date = .now,
        taxYear: Int = 0,
        jurisdiction: String = "",
        taxCategory: TaxCategory = .other,
        extractedText: String = "",
        imageRelativePath: String = "",
        scannedAt: Date = .now,
        isVerified: Bool = false,
        transaction: Transaction? = nil
    ) {
        self.merchantName = merchantName
        self.amount = amount
        self.currencyCodeRawValue = currencyCode.rawValue
        self.documentDate = documentDate
        self.taxYear = taxYear
        self.jurisdiction = jurisdiction
        self.taxCategoryRawValue = taxCategory.rawValue
        self.extractedText = extractedText
        self.imageRelativePath = imageRelativePath
        self.scannedAt = scannedAt
        self.isVerified = isVerified
        self.transaction = transaction
    }
}
