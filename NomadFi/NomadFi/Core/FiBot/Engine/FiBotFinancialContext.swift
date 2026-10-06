import Foundation

public struct FiBotMoney: Codable, Equatable, Sendable {
    public let amount: Decimal
    public let currency: String
    public init(_ amount: Decimal, currency: String) { self.amount = amount; self.currency = currency }
    enum CodingKeys: String, CodingKey { case amount, currency }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try values.decode(String.self, forKey: .amount)
        guard raw.count <= 32, raw.range(of: "^-?[0-9]+(\\.[0-9]{1,8})?$", options: .regularExpression) != nil,
              let amount = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !amount.isNaN else {
            throw DecodingError.dataCorruptedError(forKey: .amount, in: values, debugDescription: "Expected a finite decimal string")
        }
        self.amount = amount
        currency = try values.decode(String.self, forKey: .currency)
    }
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(NSDecimalNumber(decimal: amount).stringValue, forKey: .amount)
        try values.encode(currency, forKey: .currency)
    }
}

public enum FiBotVerification: String, Codable, Sendable { case observed, confirmed, inferred, missing }
public enum FiBotAccountKind: String, Codable, Sendable { case cash, credit, restricted }

public struct FiBotCashAccount: Codable, Sendable {
    public var id: String
    public var displayName: String?
    public var kind: FiBotAccountKind
    public var available: FiBotMoney
    public var protectedReserve: Decimal
    public var observedOn: String
    public var verification: FiBotVerification
    public init(id: String, kind: FiBotAccountKind = .cash, available: FiBotMoney, protectedReserve: Decimal,
                observedOn: String, verification: FiBotVerification) {
        self.id = id; self.kind = kind; self.available = available; self.protectedReserve = protectedReserve
        self.observedOn = observedOn; self.verification = verification
    }
}

public enum FiBotFlowKind: String, Codable, Sendable {
    case netIncome, essential, debtPayment, discretionary, optionalGoal, transferIn, transferOut
    public var isInflow: Bool { self == .netIncome || self == .transferIn }
}

public struct FiBotCashFlow: Codable, Sendable {
    public var id: String
    public var accountID: String
    public var date: String
    public var money: FiBotMoney
    public var kind: FiBotFlowKind
    public var verification: FiBotVerification
    public var transferID: String?
    public var commitmentID: String?
    public init(id: String, accountID: String, date: String, money: FiBotMoney, kind: FiBotFlowKind,
                verification: FiBotVerification = .confirmed, transferID: String? = nil, commitmentID: String? = nil) {
        self.id = id; self.accountID = accountID; self.date = date; self.money = money
        self.kind = kind; self.verification = verification; self.transferID = transferID; self.commitmentID = commitmentID
    }
}

public struct FiBotCommitment: Codable, Sendable {
    public var id: String
    public var accountID: String
    public var money: FiBotMoney
    public var expiresOn: String
    public init(id: String, accountID: String, money: FiBotMoney, expiresOn: String) {
        self.id = id; self.accountID = accountID; self.money = money; self.expiresOn = expiresOn
    }
}

public struct FiBotCoverage: Codable, Sendable {
    public var incomeConfirmed: Bool
    public var obligationsConfirmed: Bool
    public var accountsComplete: Bool
    public var spendingIncluded: Bool
    public var debtPaymentsIncluded: Bool
    public init(incomeConfirmed: Bool = false, obligationsConfirmed: Bool = false, accountsComplete: Bool = false,
                spendingIncluded: Bool = false, debtPaymentsIncluded: Bool = false) {
        self.incomeConfirmed = incomeConfirmed; self.obligationsConfirmed = obligationsConfirmed
        self.accountsComplete = accountsComplete; self.spendingIncluded = spendingIncluded
        self.debtPaymentsIncluded = debtPaymentsIncluded
    }
}

public struct FiBotFinancialContext: Codable, Sendable {
    public var evaluatedOn: String
    public var horizonEnd: String
    public var accounts: [FiBotCashAccount]
    public var flows: [FiBotCashFlow]
    public var commitments: [FiBotCommitment]
    public var coverage: FiBotCoverage
    public init(evaluatedOn: String, horizonEnd: String, accounts: [FiBotCashAccount], flows: [FiBotCashFlow],
                commitments: [FiBotCommitment] = [], coverage: FiBotCoverage) {
        self.evaluatedOn = evaluatedOn; self.horizonEnd = horizonEnd; self.accounts = accounts
        self.flows = flows; self.commitments = commitments; self.coverage = coverage
    }
}

public struct FiBotPurchase: Codable, Sendable {
    public var fundingAccountID: String
    public var allInCost: FiBotMoney
    public var costsComplete: Bool
    public var ownershipCosts: [FiBotCashFlow]
    public init(fundingAccountID: String, allInCost: FiBotMoney, costsComplete: Bool, ownershipCosts: [FiBotCashFlow] = []) {
        self.fundingAccountID = fundingAccountID; self.allInCost = allInCost
        self.costsComplete = costsComplete; self.ownershipCosts = ownershipCosts
    }
}

public struct FiBotPolicy: Codable, Sendable {
    public var version: String
    public var maximumBalanceAgeDays: Int
    public var incomeReductionPercent: Decimal
    public var expenseIncreasePercent: Decimal
    public var incomeDelayDays: Int
    public init(version: String = "cash-flow-v1", maximumBalanceAgeDays: Int = 2,
                incomeReductionPercent: Decimal = 10, expenseIncreasePercent: Decimal = 10, incomeDelayDays: Int = 3) {
        self.version = version; self.maximumBalanceAgeDays = maximumBalanceAgeDays
        self.incomeReductionPercent = incomeReductionPercent; self.expenseIncreasePercent = expenseIncreasePercent
        self.incomeDelayDays = incomeDelayDays
    }
}
