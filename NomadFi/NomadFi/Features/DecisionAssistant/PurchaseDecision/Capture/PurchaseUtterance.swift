// PurchaseUtterance.swift
// NomadFi
//
// What a spoken sentence about a purchase contained.

import Foundation

/// The parts of a purchase found in something the person said, such as
/// "forty dollars at Whole Foods". Anything not said stays `nil`, so it
/// never overwrites what is already entered.
struct PurchaseUtterance: Equatable, Sendable {
    var merchantName: String?
    var amount: Double?
    var currency: CurrencyCode?
    var category: MerchantCategory?

    /// Whether anything usable was understood.
    var isEmpty: Bool { merchantName == nil && amount == nil && currency == nil && category == nil }
}
