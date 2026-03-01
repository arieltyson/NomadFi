// ReceiptCategorizer.swift
// NomadFi
//
// Rule-based auto-categorization engine for scanned receipts.
// Categorizes by tax category and infers jurisdiction from receipt text.

import Foundation

/// Auto-categorizes receipts based on keyword matching in extracted OCR text.
///
/// Uses a rule-based approach to assign both a ``TaxCategory`` and an
/// inferred jurisdiction (ISO country code) based on merchant names,
/// addresses, and currency symbols found in the receipt.
///
/// - Note: This is a pure-function engine (enum with static methods) for
///   testability and thread safety. No side effects or stored state.
enum ReceiptCategorizer {

    /// The result of auto-categorization.
    struct Result: Sendable {
        let category: TaxCategory
        let jurisdiction: String?
        let confidence: Confidence
    }

    /// How confident the categorizer is in its assignment.
    enum Confidence: Sendable {
        case high
        case medium
        case low
    }

    // MARK: - Public API

    /// Categorizes receipt text into a tax category and jurisdiction.
    ///
    /// - Parameter text: The raw OCR text extracted from a receipt.
    /// - Returns: A categorization result with category, jurisdiction, and confidence.
    static func categorize(text: String) -> Result {
        let category = detectCategory(from: text)
        let jurisdiction = detectJurisdiction(from: text)

        let confidence: Confidence = switch (category, jurisdiction) {
        case (.other, nil): .low
        case (.other, _), (_, nil): .medium
        default: .high
        }

        return Result(
            category: category,
            jurisdiction: jurisdiction,
            confidence: confidence
        )
    }

    // MARK: - Category Detection

    private static func detectCategory(from text: String) -> TaxCategory {
        let lowercased = text.lowercased()

        // Education & Tuition
        if matchesAny(lowercased, keywords: educationKeywords) {
            return lowercased.contains("tuition") ? .tuition : .education
        }

        // Medical
        if matchesAny(lowercased, keywords: medicalKeywords) {
            return .medical
        }

        // Textbooks & Supplies
        if matchesAny(lowercased, keywords: textbookKeywords) {
            return .textbooks
        }

        // Housing
        if matchesAny(lowercased, keywords: housingKeywords) {
            return .housingExpense
        }

        // Income & Wages
        if matchesAny(lowercased, keywords: wageKeywords) {
            return .wages
        }

        // Scholarship
        if matchesAny(lowercased, keywords: scholarshipKeywords) {
            return .scholarshipIncome
        }

        // Treaty Benefits
        if matchesAny(lowercased, keywords: treatyKeywords) {
            return .treatyBenefits
        }

        return .other
    }

    // MARK: - Jurisdiction Detection

    private static func detectJurisdiction(from text: String) -> String? {
        let lowercased = text.lowercased()

        // US indicators
        if matchesAny(lowercased, keywords: usKeywords) {
            return "US"
        }

        // Canada indicators
        if matchesAny(lowercased, keywords: canadaKeywords) {
            return "CA"
        }

        // Trinidad & Tobago indicators
        if matchesAny(lowercased, keywords: trinidadKeywords) {
            return "TT"
        }

        // UK indicators
        if matchesAny(lowercased, keywords: ukKeywords) {
            return "GB"
        }

        // Currency-based fallback
        if text.contains("$") && !text.contains("CA$") && !text.contains("TT$") {
            return "US"
        }
        if text.contains("CA$") { return "CA" }
        if text.contains("TT$") { return "TT" }
        if text.contains("£") { return "GB" }
        if text.contains("€") { return nil } // Multiple possible jurisdictions

        return nil
    }

    // MARK: - Keyword Lists

    private static func matchesAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static let educationKeywords = [
        "tuition", "university", "college", "school", "campus",
        "registrar", "student", "academic", "semester", "enrollment",
        "course fee", "lab fee",
    ]

    private static let medicalKeywords = [
        "pharmacy", "hospital", "clinic", "medical", "health",
        "prescription", "doctor", "dental", "optometry", "urgent care",
        "walgreens", "cvs", "rite aid",
    ]

    private static let textbookKeywords = [
        "textbook", "bookstore", "amazon books", "chegg",
        "course materials", "lab manual", "study guide",
    ]

    private static let housingKeywords = [
        "rent", "lease", "apartment", "housing", "dormitory",
        "utilities", "electric", "gas bill", "water bill", "internet",
    ]

    private static let wageKeywords = [
        "payroll", "pay stub", "earnings", "salary", "wages",
        "w-2", "w2", "compensation", "direct deposit",
    ]

    private static let scholarshipKeywords = [
        "scholarship", "fellowship", "grant", "stipend", "award",
        "financial aid", "1042-s", "1042s",
    ]

    private static let treatyKeywords = [
        "treaty", "tax treaty", "article", "withholding",
        "non-resident", "nra", "1042",
    ]

    private static let usKeywords = [
        "united states", "usa", " ca ", "california", "new york",
        "texas", "florida", "san francisco", "los angeles",
        "seattle", "boston", "chicago",
    ]

    private static let canadaKeywords = [
        "canada", "ontario", "british columbia", "alberta",
        "toronto", "vancouver", "montreal", "ottawa",
        "gst", "hst", "pst",
    ]

    private static let trinidadKeywords = [
        "trinidad", "tobago", "port of spain", "san fernando",
        "chaguanas",
    ]

    private static let ukKeywords = [
        "united kingdom", "england", "london", "manchester",
        "vat", "hmrc",
    ]
}
