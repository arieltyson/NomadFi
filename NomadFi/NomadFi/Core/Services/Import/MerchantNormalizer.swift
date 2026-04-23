// MerchantNormalizer.swift
// NomadFi
//
// Deterministic merchant-name cleanup. Strips common processor
// prefixes, trailing store numbers, and repeated punctuation so
// `SubscriptionDetector` and `TransactionImportDeduper` can cluster
// "SQ *COFFEE SHOP #1234" and "Coffee Shop" as the same merchant.
//
// The rules are conservative on purpose — we'd rather leave an
// unfamiliar prefix alone than collapse two distinct merchants into
// one. The original `merchantName` is always preserved on the
// `Transaction`; the normalized form is a separate persisted field
// used only for matching.
//
// No LLM, no heuristic scoring, no remote lookup. Every rule below
// is a literal regex or prefix the tests pin.

import Foundation

/// Pure merchant-name normalizer. Call ``normalize(_:)`` for the
/// canonical short form used by dedupe + subscription detection.
enum MerchantNormalizer {

    /// Common payment-processor / payment-network prefixes. Order
    /// matters: longer prefixes go first so "AMEX *" doesn't
    /// accidentally eat "AMEX" literals once trailing-store-number
    /// stripping has been applied downstream.
    static let processorPrefixes: [String] = [
        "SQ *",
        "SQ*",
        "TST*",
        "TST* ",
        "SP *",
        "SP* ",
        "PAYPAL *",
        "PAYPAL*",
        "PP*",
        "AMZN*",
        "AMAZON*",
        "AMZN MKTP US*",
        "AMZN MKTP CA*",
        "APPLE.COM/BILL",
        "ETSY*",
        "IC*",
        "IN *",
    ]

    // MARK: - Public API

    /// Canonical form for matching. Never presented in the UI — the
    /// view always shows the original `merchantName`.
    ///
    /// Empty / whitespace-only input returns an empty string so the
    /// deduper gracefully treats it as "no merchant signal" rather
    /// than matching every blank row together.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Uppercase first so prefix / suffix rules below can stay
        // case-free.
        var working = trimmed.uppercased()

        // Strip processor prefixes (iteratively — some merchants
        // nest them, e.g. "PP*SQ *COFFEE").
        var strippedSomething = true
        while strippedSomething {
            strippedSomething = false
            for prefix in processorPrefixes {
                if working.hasPrefix(prefix) {
                    working = String(working.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespaces)
                    strippedSomething = true
                }
            }
        }

        // Strip trailing store numbers / transaction suffixes. Each
        // rule only fires on the *tail* of the name. The CITY-ST-ZIP
        // pattern runs first because it subsumes the zip that the
        // generic store-number regex would otherwise greedily claim,
        // leaving the city and state orphaned on the tail.
        working = stripTrailingCityStateZip(working)
        working = stripTrailingStoreNumber(working)
        working = stripTrailingHashNumber(working)
        working = stripTrailingShortDate(working)

        // Collapse runs of repeated punctuation and whitespace.
        working = collapseRepeatedPunctuation(working)
        working = collapseInternalWhitespace(working)

        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private trailing-pattern strippers

    /// Removes `" 01234"`, `" 0123"`, `" 12345"` — trailing
    /// numeric store identifiers common on retail exports.
    private static func stripTrailingStoreNumber(_ input: String) -> String {
        input.replacing(
            #/\s+\d{3,6}$/#,
            with: ""
        )
    }

    /// Removes `" #12345"`-style trailing store/location markers.
    private static func stripTrailingHashNumber(_ input: String) -> String {
        input.replacing(
            #/\s+#\d+$/#,
            with: ""
        )
    }

    /// Removes trailing `" 04/23"` / `" 04-23"` date markers that
    /// some merchants append.
    private static func stripTrailingShortDate(_ input: String) -> String {
        input.replacing(
            #/\s+\d{1,2}[-/]\d{1,2}(?:[-/]\d{2,4})?$/#,
            with: ""
        )
    }

    /// Removes a trailing `" CITY ST 12345"` block. Tokenises rather
    /// than running one greedy regex: with unanchored matching, a
    /// merchant whose own name contains an uppercase word (e.g.
    /// "COFFEE SHOP NEW YORK NY 10001") gets its boundary eaten if
    /// the regex can start matching at either `" SHOP"` or `" NEW"`.
    /// Working from the right lets us anchor the state + zip tail
    /// deterministically and then consume a conservative 1–2-word
    /// city, leaving the rest as merchant name.
    private static func stripTrailingCityStateZip(_ input: String) -> String {
        var tokens = input
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard tokens.count >= 4 else { return input }

        let zipToken = tokens[tokens.count - 1]
        let stateToken = tokens[tokens.count - 2]

        let zipIsFiveDigits = zipToken.count == 5
            && zipToken.allSatisfy(\.isNumber)
        let stateIsTwoLetters = stateToken.count == 2
            && stateToken.allSatisfy { $0.isLetter && $0.isUppercase }

        guard zipIsFiveDigits, stateIsTwoLetters else { return input }

        // 5+ tokens total → treat the two preceding tokens as a
        // two-word city ("NEW YORK", "SAN FRANCISCO"). Exactly 4
        // tokens → single-word city, leaving a single-word merchant.
        let cityTokenCount = tokens.count >= 5 ? 2 : 1
        tokens.removeLast(cityTokenCount + 2)
        return tokens.joined(separator: " ")
    }

    private static func collapseRepeatedPunctuation(_ input: String) -> String {
        input
            .replacing(#/!{2,}/#, with: "!")
            .replacing(#/\*{2,}/#, with: "*")
            .replacing(#/-{2,}/#, with: "-")
    }

    private static func collapseInternalWhitespace(_ input: String) -> String {
        input.replacing(#/\s+/#, with: " ")
    }
}
