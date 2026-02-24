import Foundation

enum BillingFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case annual = "annual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annual: "Annual"
        }
    }

    var annualizedMultiplier: Double {
        switch self {
        case .weekly: 52
        case .monthly: 12
        case .quarterly: 4
        case .annual: 1
        }
    }
}
