import Foundation

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        }
    }
}
