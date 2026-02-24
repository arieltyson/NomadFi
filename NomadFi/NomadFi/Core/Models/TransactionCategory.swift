import Foundation

enum TransactionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case food = "food"
    case transport = "transport"
    case housing = "housing"
    case education = "education"
    case medical = "medical"
    case entertainment = "entertainment"
    case shopping = "shopping"
    case utilities = "utilities"
    case subscription = "subscription"
    case transfer = "transfer"
    case income = "income"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: "Food and Dining"
        case .transport: "Transportation"
        case .housing: "Housing"
        case .education: "Education"
        case .medical: "Medical"
        case .entertainment: "Entertainment"
        case .shopping: "Shopping"
        case .utilities: "Utilities"
        case .subscription: "Subscription"
        case .transfer: "Transfer"
        case .income: "Income"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car"
        case .housing: "house"
        case .education: "graduationcap"
        case .medical: "cross.case"
        case .entertainment: "film"
        case .shopping: "bag"
        case .utilities: "bolt"
        case .subscription: "arrow.triangle.2.circlepath"
        case .transfer: "arrow.left.arrow.right"
        case .income: "banknote"
        case .other: "ellipsis.circle"
        }
    }
}
