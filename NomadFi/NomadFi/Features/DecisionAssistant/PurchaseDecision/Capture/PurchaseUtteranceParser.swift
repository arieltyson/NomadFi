// PurchaseUtteranceParser.swift
// NomadFi
//
// Reads a merchant, amount, currency and category out of a spoken sentence.

import Foundation

/// A deterministic reader for short spoken purchases.
///
/// Speech recognition already writes numbers as digits ("$40"), so this
/// only has to find the amount, a currency if one was named, the merchant
/// after "at" or "from", and a category from a few plain keywords. It
/// never guesses: a part it cannot find is left out.
enum PurchaseUtteranceParser {

    static func parse(_ text: String) -> PurchaseUtterance {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return PurchaseUtterance() }
        let lowered = trimmed.lowercased()
        return PurchaseUtterance(
            merchantName: merchant(in: trimmed),
            amount: amount(in: lowered),
            currency: currency(in: lowered),
            category: category(in: lowered)
        )
    }

    // MARK: - Parts

    private static func amount(in text: String) -> Double? {
        guard let match = text.firstMatch(of: /(\d[\d,]*(?:\.\d{1,2})?)/) else { return nil }
        return Double(match.output.1.replacing(",", with: ""))
    }

    private static let currencyWords: [(CurrencyCode, [String])] = [
        (.usd, ["us dollar", "u.s. dollar", "american dollar", "usd"]),
        (.cad, ["canadian", "cad"]),
        (.ttd, ["trinidad", "tt dollar", "ttd"]),
        (.gbp, ["pound", "gbp", "quid"]),
        (.eur, ["euro", "eur"]),
        (.inr, ["rupee", "inr"]),
        (.ngn, ["naira", "ngn"]),
        (.cny, ["yuan", "renminbi", "cny"]),
    ]

    private static func currency(in text: String) -> CurrencyCode? {
        currencyWords.first { _, words in words.contains(where: text.contains) }?.0
    }

    /// The words after the last "at" or "from", up to a trailing "for …".
    private static func merchant(in text: String) -> String? {
        guard let match = text.matches(of: /\b(?:at|from)\s+(.+)/.ignoresCase()).last else { return nil }
        var name = String(match.output.1)
        if let tail = name.firstMatch(of: /\s+(?:for|in|with|using|on)\s+.*/.ignoresCase()) {
            name.removeSubrange(tail.range)
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return name.isEmpty ? nil : name
    }

    private static let categoryWords: [(MerchantCategory, [String])] = [
        (.groceries, ["grocer", "supermarket", "whole foods", "costco", "walmart", "safeway", "no frills", "superstore"]),
        (.dining, ["restaurant", "dinner", "lunch", "breakfast", "coffee", "cafe", "café", "starbucks", "tim hortons", "pizza", "takeout", "uber eats", "doordash"]),
        (.travel, ["flight", "airline", "hotel", "airbnb", "air canada", "westjet"]),
        (.transit, ["uber", "lyft", "taxi", "bus", "train", "transit", "gas", "fuel", "parking"]),
        (.onlineShopping, ["amazon", "online", "ebay", "etsy"]),
        (.health, ["pharmacy", "doctor", "dentist", "clinic", "shoppers drug mart"]),
        (.school, ["tuition", "textbook", "bookstore", "university", "college"]),
        (.subscriptions, ["subscription", "netflix", "spotify", "membership"]),
        (.utilities, ["phone bill", "internet", "hydro", "electricity", "utility"]),
    ]

    private static func category(in text: String) -> MerchantCategory? {
        categoryWords.first { _, words in words.contains(where: text.contains) }?.0
    }
}
