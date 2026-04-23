// MerchantCategoryInferrer.swift
// NomadFi
//
// Tiny, deterministic keyword map from a normalized merchant name
// to a `TransactionCategory`. This is *not* an LLM classifier. It's
// a modest auto-fill so common merchants land in the obvious
// bucket; ambiguous rows stay `.other` and the UI surfaces that
// honestly.
//
// If `MerchantCategoryInferrer.infer(...)` ever gets more complex
// than a keyword table, step back and reconsider the scope — the
// whole point of this phase is deterministic ingestion, not ML.

import Foundation

/// Pure keyword-based inference.
enum MerchantCategoryInferrer {

    /// Returns the user-visible category the deduper / preview
    /// should default to for a given normalized merchant. `.other`
    /// is a valid, honest answer — callers must be willing to
    /// accept it and let the user edit after confirmation.
    static func infer(
        from normalizedMerchant: String
    ) -> TransactionCategory {
        let haystack = normalizedMerchant.uppercased()
        guard !haystack.isEmpty else { return .other }

        for (category, keywords) in keywordMap {
            if keywords.contains(where: haystack.contains) {
                return category
            }
        }
        return .other
    }

    // MARK: - Private

    /// Intentionally small. Each keyword is evaluated as a substring
    /// against the uppercased normalized merchant name.
    private static let keywordMap: [(TransactionCategory, [String])] = [
        (.food, [
            "GROCER", "SUPERMARKET", "WHOLE FOODS", "LOBLAWS",
            "STARBUCKS", "COFFEE", "CAFE", "RESTAURANT", "PIZZA",
            "MCDONALD", "CHIPOTLE", "SUBWAY", "TACO", "BURGER",
            "DINER", "KITCHEN", "BAKERY", "DOORDASH", "UBER EATS",
            "SKIP THE DISHES",
        ]),
        (.transport, [
            "UBER", "LYFT", "TAXI", "MTA", "BART", "CALTRAIN",
            "TRANSIT", "TRANSPORTATION", "PARKING", "SHELL",
            "CHEVRON", "EXXON", "BP ", "PETRO-CANADA", "ESSO",
        ]),
        (.housing, [
            "RENT", "LEASE", "AIRBNB", "HOTEL", "MOTEL", "LODGE",
            "PROPERTY", "LANDLORD", "MORTGAGE",
        ]),
        (.education, [
            "UNIVERSITY", "COLLEGE", "SCHOOL", "TUITION", "STUDENT",
            "COURSERA", "EDX", "UDEMY",
        ]),
        (.medical, [
            "PHARMACY", "CLINIC", "HOSPITAL", "DENTAL", "DOCTOR",
            "CVS", "WALGREENS", "SHOPPERS DRUG", "HEALTH",
        ]),
        (.entertainment, [
            "NETFLIX", "SPOTIFY", "APPLE MUSIC", "HULU", "DISNEY",
            "HBO", "CINEMA", "MOVIE", "THEATRE", "STEAM", "PLAYSTATION",
            "XBOX",
        ]),
        (.shopping, [
            "AMAZON", "WALMART", "TARGET", "BEST BUY", "COSTCO",
            "IKEA", "APPLE STORE",
        ]),
        (.utilities, [
            "ELECTRIC", "HYDRO", "GAS BILL", "WATER", "INTERNET",
            "VERIZON", "ROGERS", "BELL CANADA", "COMCAST", "AT&T",
            "T-MOBILE", "FIDO",
        ]),
        (.subscription, [
            "SUBSCRIPTION", "PREMIUM", "MONTHLY PLAN", "YEARLY PLAN",
        ]),
        (.income, [
            "PAYROLL", "DIRECT DEPOSIT", "EMPLOYER", "SALARY",
        ]),
        (.transfer, [
            "TRANSFER", "E-TRANSFER", "ETRANSFER", "INTERAC",
            "ZELLE", "VENMO", "CASH APP",
        ]),
    ]
}
