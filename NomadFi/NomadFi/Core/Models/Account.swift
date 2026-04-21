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

    // Provenance fields for `foreignTransactionFeePercent`. Stored as
    // CloudKit-safe primitives: all optional with sensible defaults. See
    // `SourceProvenance` and `docs/README.md` for the evidence hierarchy
    // these values map into.
    var foreignTransactionFeeSourceName: String? = nil
    var foreignTransactionFeeSourceURL: String? = nil
    var foreignTransactionFeeSourceConfidenceRaw: String? = nil
    var foreignTransactionFeeSourceVerifiedAt: Date? = nil
    var foreignTransactionFeeSourceNotes: String? = nil

    var createdAt: Date = Date.now
    var lastUpdatedAt: Date = Date.now

    var jurisdictionProfile: JurisdictionProfile?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \Subscription.account)
    var subscriptions: [Subscription]?

    var currencyCode: CurrencyCode? {
        CurrencyCode(rawValue: currencyCodeRawValue)
    }

    var accountType: AccountType? {
        AccountType(rawValue: accountTypeRawValue)
    }

    /// Provenance for the `foreignTransactionFeePercent` value.
    ///
    /// Reconstructs a ``SourceProvenance`` from the persisted primitive
    /// fields. Defaults to ``SourceProvenance/userEnteredAccountFee(accessedAt:)``
    /// when no confidence has been recorded — user-entered fees are never
    /// treated as verified without an explicit upgrade.
    var foreignTransactionFeeProvenance: SourceProvenance {
        let confidence = foreignTransactionFeeSourceConfidenceRaw
            .flatMap(SourceConfidence.init(rawValue:))
            ?? .userProvided

        let scope = JurisdictionScope(countryCode: jurisdiction)

        if let name = foreignTransactionFeeSourceName, !name.isEmpty {
            return SourceProvenance(
                name: name,
                urlString: foreignTransactionFeeSourceURL,
                type: confidence.isVerified ? .issuerDisclosure : .userEntered,
                confidence: confidence,
                jurisdiction: scope,
                accessedAt: foreignTransactionFeeSourceVerifiedAt,
                publishedAt: nil,
                notes: foreignTransactionFeeSourceNotes
            )
        }

        var provenance = SourceProvenance.userEnteredAccountFee(
            accessedAt: foreignTransactionFeeSourceVerifiedAt
        )
        provenance.jurisdiction = scope
        return provenance
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
        foreignTransactionFeeSourceName: String? = nil,
        foreignTransactionFeeSourceURL: String? = nil,
        foreignTransactionFeeSourceConfidence: SourceConfidence? = nil,
        foreignTransactionFeeSourceVerifiedAt: Date? = nil,
        foreignTransactionFeeSourceNotes: String? = nil,
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
        self.foreignTransactionFeeSourceName = foreignTransactionFeeSourceName
        self.foreignTransactionFeeSourceURL = foreignTransactionFeeSourceURL
        self.foreignTransactionFeeSourceConfidenceRaw = foreignTransactionFeeSourceConfidence?.rawValue
        self.foreignTransactionFeeSourceVerifiedAt = foreignTransactionFeeSourceVerifiedAt
        self.foreignTransactionFeeSourceNotes = foreignTransactionFeeSourceNotes
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.jurisdictionProfile = jurisdictionProfile
        self.transactions = transactions
        self.subscriptions = subscriptions
    }
}
