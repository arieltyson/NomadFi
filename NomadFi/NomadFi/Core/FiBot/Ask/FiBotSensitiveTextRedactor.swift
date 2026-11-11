// FiBotSensitiveTextRedactor.swift
// NomadFi
//
// Keeps long identifying numbers out of what FiBot reads and says.

import Foundation

/// Masks numbers that identify an account rather than describe money.
///
/// NomadFi never stores full card numbers, PINs or passwords, but names
/// written by banks and merchants can carry the tail of a card number,
/// a phone number or a reference. Those are masked before a name reaches
/// the model, and any card-length number is masked again in the answer,
/// so nothing of that shape is shown even if it arrives some other way.
enum FiBotSensitiveTextRedactor {

    /// The digits kept at the end of a masked number, as on a receipt.
    static let visibleDigits = 4

    /// Masks every run of five or more digits in a name, such as the
    /// card ending a bank appends to an account name.
    static func redactingName(_ name: String) -> String {
        mask(name, matching: /\d(?:[ -]?\d){4,}/)
    }

    /// Masks anything the length of a payment card number in an answer.
    static func redactingAnswer(_ text: String) -> String {
        mask(text, matching: /\d(?:[ -]?\d){12,18}/)
    }

    private static func mask(_ text: String, matching pattern: Regex<Substring>) -> String {
        text.replacing(pattern) { match in
            "••\(match.output.filter(\.isNumber).suffix(visibleDigits))"
        }
    }
}
