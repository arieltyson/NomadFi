// CurrencyCodeAppEnum.swift
// NomadFi
//
// App Intents adapter for ``CurrencyCode``. Kept separate from the
// core model so the domain enum never has to import `AppIntents` —
// `CurrencyCode` is used by SwiftData models, pure engines, and
// value types across the app, and none of those should depend on
// the `AppIntents` framework.
//
// One-to-one mapping with ``CurrencyCode`` so adding a case on the
// core enum requires a symmetric case here; Swift's exhaustive
// switching keeps that contract honest.

import AppIntents

/// App Intents adapter for the user-picked purchase currency.
///
/// Surfaces the same eight currencies as ``CurrencyCode`` inside
/// Siri and the Shortcuts app. Display labels are the ISO code plus
/// the long display name so voice pickers read clearly.
enum CurrencyCodeAppEnum: String, AppEnum {

    case usd
    case cad
    case ttd
    case gbp
    case eur
    case inr
    case ngn
    case cny

    // MARK: - AppEnum

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        "Currency"

    static let caseDisplayRepresentations: [CurrencyCodeAppEnum: DisplayRepresentation] = [
        .usd: "USD — US Dollar",
        .cad: "CAD — Canadian Dollar",
        .ttd: "TTD — Trinidad and Tobago Dollar",
        .gbp: "GBP — British Pound",
        .eur: "EUR — Euro",
        .inr: "INR — Indian Rupee",
        .ngn: "NGN — Nigerian Naira",
        .cny: "CNY — Chinese Yuan",
    ]
}

// MARK: - Bridging

extension CurrencyCodeAppEnum {

    /// Maps the App Intents adapter back to the core model enum.
    var currencyCode: CurrencyCode {
        switch self {
        case .usd: .usd
        case .cad: .cad
        case .ttd: .ttd
        case .gbp: .gbp
        case .eur: .eur
        case .inr: .inr
        case .ngn: .ngn
        case .cny: .cny
        }
    }

    /// Mirror constructor — lets callers translate a core currency
    /// into an intent-facing currency when pre-seeding parameters.
    init(_ currency: CurrencyCode) {
        switch currency {
        case .usd: self = .usd
        case .cad: self = .cad
        case .ttd: self = .ttd
        case .gbp: self = .gbp
        case .eur: self = .eur
        case .inr: self = .inr
        case .ngn: self = .ngn
        case .cny: self = .cny
        }
    }
}
