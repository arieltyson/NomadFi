// InputSanitizer.swift
// NomadFi
//
// Provides input sanitization and validation for user-entered text
// and financial amounts. Prevents injection, invalid data, and
// ensures all stored values are within safe bounds.

import Foundation

/// Centralized input sanitization for all user-entered data.
///
/// Every text field and numeric input in NomadFi passes through
/// these methods before being stored in SwiftData or displayed.
/// This prevents:
/// - Control character injection
/// - Unreasonably long strings consuming storage
/// - NaN, Infinity, and other invalid numeric values
/// - Negative-zero and unreasonably large amounts
enum InputSanitizer {

    // MARK: - Text Sanitization

    /// Maximum length for short text fields (merchant names, account names, etc.).
    static let maxShortTextLength = 200

    /// Maximum length for long text fields (notes, OCR extracted text).
    static let maxLongTextLength = 5_000

    /// Sanitizes a short text input by stripping control characters and enforcing length.
    ///
    /// Suitable for merchant names, account names, service names, institution names.
    ///
    /// - Parameter text: The raw user input.
    /// - Returns: A sanitized string safe for storage and display.
    static func sanitizeShortText(_ text: String) -> String {
        sanitize(text, maxLength: maxShortTextLength)
    }

    /// Sanitizes a long text input (notes, OCR output).
    static func sanitizeLongText(_ text: String) -> String {
        sanitize(text, maxLength: maxLongTextLength)
    }

    /// Core sanitization: strips control characters, trims whitespace, enforces length.
    private static func sanitize(_ text: String, maxLength: Int) -> String {
        let stripped = text.unicodeScalars.filter { scalar in
            // Allow all printable characters, whitespace, and newlines
            // Reject control characters (U+0000–U+001F except \t \n \r, and U+007F–U+009F)
            if scalar.value < 0x20 {
                return scalar == "\t" || scalar == "\n" || scalar == "\r"
            }
            if scalar.value >= 0x7F && scalar.value <= 0x9F {
                return false
            }
            return true
        }

        let cleaned = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespaces)

        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength))
        }
        return cleaned
    }

    // MARK: - Amount Validation

    /// Maximum currency amount accepted by NomadFi.
    ///
    /// 10 billion covers even hyperinflated currencies while preventing
    /// accidental astronomical values from corrupting calculations.
    static let maxAmount: Double = 10_000_000_000

    /// Validates and clamps a currency amount to a safe range.
    ///
    /// Rejects NaN, Infinity, negative-zero, and values exceeding ``maxAmount``.
    ///
    /// - Parameter amount: The raw numeric value.
    /// - Returns: A validated amount, or `nil` if the input is irrecoverable.
    static func validateAmount(_ amount: Double) -> Double? {
        guard amount.isFinite else { return nil }
        guard !amount.isNaN else { return nil }

        // Normalize negative zero
        let normalized = amount == 0 ? 0 : amount

        // Clamp to reasonable bounds
        guard abs(normalized) <= maxAmount else { return nil }

        return normalized
    }

    /// Validates an exchange rate is within plausible bounds.
    ///
    /// - Parameter rate: The exchange rate to validate.
    /// - Returns: The rate if valid, or `nil` if out of bounds.
    static func validateExchangeRate(_ rate: Double) -> Double? {
        guard rate.isFinite, !rate.isNaN else { return nil }
        guard rate > 0 else { return nil }
        // No currency pair exceeds 100,000:1 in practice
        guard rate <= 100_000 else { return nil }
        return rate
    }
}
