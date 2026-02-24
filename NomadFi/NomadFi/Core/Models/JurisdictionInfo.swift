import Foundation

/// Static jurisdiction data for the onboarding picker and account setup.
///
/// Each entry maps an ISO 3166-1 country code to its display name,
/// flag emoji, and primary currency. Used during onboarding to populate
/// `JurisdictionProfile` records in SwiftData.
struct JurisdictionInfo: Identifiable, Hashable, Sendable {

    let id: String
    let name: String
    let flag: String
    let currencyCode: CurrencyCode

    /// Jurisdictions commonly relevant to international students.
    ///
    /// Ordered by most common international student corridors first.
    static let supported: [JurisdictionInfo] = [
        JurisdictionInfo(id: "TT", name: "Trinidad and Tobago", flag: "\u{1F1F9}\u{1F1F9}", currencyCode: .ttd),
        JurisdictionInfo(id: "CA", name: "Canada", flag: "\u{1F1E8}\u{1F1E6}", currencyCode: .cad),
        JurisdictionInfo(id: "US", name: "United States", flag: "\u{1F1FA}\u{1F1F8}", currencyCode: .usd),
        JurisdictionInfo(id: "GB", name: "United Kingdom", flag: "\u{1F1EC}\u{1F1E7}", currencyCode: .gbp),
        JurisdictionInfo(id: "IN", name: "India", flag: "\u{1F1EE}\u{1F1F3}", currencyCode: .inr),
        JurisdictionInfo(id: "NG", name: "Nigeria", flag: "\u{1F1F3}\u{1F1EC}", currencyCode: .ngn),
        JurisdictionInfo(id: "CN", name: "China", flag: "\u{1F1E8}\u{1F1F3}", currencyCode: .cny),
        JurisdictionInfo(id: "DE", name: "Germany", flag: "\u{1F1E9}\u{1F1EA}", currencyCode: .eur),
        JurisdictionInfo(id: "FR", name: "France", flag: "\u{1F1EB}\u{1F1F7}", currencyCode: .eur),
    ]
}
