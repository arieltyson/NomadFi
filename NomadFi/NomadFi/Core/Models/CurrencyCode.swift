import Foundation

enum CurrencyCode: String, Codable, CaseIterable, Identifiable, Sendable {
    case usd = "USD"
    case cad = "CAD"
    case ttd = "TTD"
    case gbp = "GBP"
    case eur = "EUR"
    case inr = "INR"
    case ngn = "NGN"
    case cny = "CNY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: "US Dollar"
        case .cad: "Canadian Dollar"
        case .ttd: "Trinidad and Tobago Dollar"
        case .gbp: "British Pound"
        case .eur: "Euro"
        case .inr: "Indian Rupee"
        case .ngn: "Nigerian Naira"
        case .cny: "Chinese Yuan"
        }
    }

    var symbol: String {
        switch self {
        case .usd: "$"
        case .cad: "CA$"
        case .ttd: "TT$"
        case .gbp: "GBP"
        case .eur: "EUR"
        case .inr: "INR"
        case .ngn: "NGN"
        case .cny: "CNY"
        }
    }
}
