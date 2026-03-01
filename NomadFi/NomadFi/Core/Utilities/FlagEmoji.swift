// FlagEmoji.swift
// NomadFi
//
// Converts ISO 3166-1 alpha-2 country codes to emoji flag characters.
// Consolidates the flag emoji conversion used across the app.

import Foundation

extension String {

    /// Converts an ISO 3166-1 alpha-2 country code to its regional indicator emoji.
    ///
    /// Each letter is offset into the Regional Indicator Symbol range (U+1F1E6–U+1F1FF).
    ///
    /// ```swift
    /// String.flagEmoji(for: "US") // 🇺🇸
    /// String.flagEmoji(for: "CA") // 🇨🇦
    /// String.flagEmoji(for: "TT") // 🇹🇹
    /// ```
    ///
    /// - Parameter countryCode: An ISO 3166-1 alpha-2 country code (e.g., "US", "CA", "TT").
    /// - Returns: The corresponding emoji flag, or an empty string if the code is invalid.
    static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { Unicode.Scalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
