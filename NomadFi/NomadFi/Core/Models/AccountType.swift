import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checking = "checking"
    case savings = "savings"
    case creditCard = "credit_card"
    case investment = "investment"
    case wallet = "wallet"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: "Checking"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .investment: "Investment"
        case .wallet: "Digital Wallet"
        }
    }

    var systemImage: String {
        switch self {
        case .checking: "banknote"
        case .savings: "building.columns"
        case .creditCard: "creditcard"
        case .investment: "chart.line.uptrend.xyaxis"
        case .wallet: "wallet.bifold"
        }
    }
}
