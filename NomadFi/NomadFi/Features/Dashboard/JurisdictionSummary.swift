// JurisdictionSummary.swift
// NomadFi
//
// One country's card on the Dashboard.

import Foundation

/// A jurisdiction with its accounts and its total in local currency.
struct JurisdictionSummary: Identifiable {

    let profile: JurisdictionProfile
    let accounts: [Account]

    /// The net-worth contribution of `accounts`, in ``currency``.
    let total: Double

    var id: String { profile.countryCode }

    /// Summarises `accounts`, which must all belong to `profile`.
    init(profile: JurisdictionProfile, accounts: [Account]) {
        self.profile = profile
        self.accounts = accounts
        self.total = accounts.reduce(0) { $0 + $1.netWorthContribution }
    }

    var currency: CurrencyCode { profile.currencyCode ?? .usd }
}
