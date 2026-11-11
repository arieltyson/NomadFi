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

    /// The currency's own sign, as written where it is used.
    var sign: String {
        switch self {
        case .usd, .cad, .ttd: "$"
        case .gbp: "£"
        case .eur: "€"
        case .inr: "₹"
        case .ngn: "₦"
        case .cny: "¥"
        }
    }

    /// The code and the sign together, such as `CAD$` or `GBP£`.
    ///
    /// Every currency is written the same way, so dollars from different
    /// countries are never mistaken for one another and no currency is
    /// shown as the default.
    var symbol: String { "\(rawValue)\(sign)" }
}
