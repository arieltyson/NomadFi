// FiBotFigureVerifier.swift
// NomadFi
//
// The check that closes Ask FiBot's loop: every figure in an answer
// must trace back to a fact NomadFi computed itself.

import Foundation

/// Checks a draft answer's figures against the facts it cites.
///
/// A language model can phrase an answer well and still get a number
/// wrong. This verifier is deterministic: it reads every figure in the
/// answer and accepts it only when it equals
///
/// - a figure in one of the cited facts, or in the question itself,
/// - that figure rounded to a whole number, or
/// - the sum or difference of two such figures, or, for a percentage,
///   their ratio.
///
/// Anything else is reported back so the model can correct itself, and
/// if it cannot, so the answer is shown with a caution instead of as
/// fact.
enum FiBotFigureVerifier {

    /// How close two amounts must be to count as the same figure.
    private static let tolerance = 0.005

    /// Checks `draft` against `sheet`.
    ///
    /// - Parameters:
    ///   - draft: The model's proposed answer.
    ///   - sheet: The facts the answer was written from.
    ///   - question: The person's question; figures they gave count as known.
    /// - Returns: The verification outcome and the cited facts that exist.
    static func verify(
        _ draft: FiBotAnswerDraft,
        against sheet: FiBotFactSheet,
        question: String
    ) -> (verification: FiBotAnswerVerification, sources: [FiBotFact]) {
        let citedIDs = Set(draft.citedFactIDs)
        let sources = sheet.facts.filter { citedIDs.contains($0.id) }

        let figures = figures(in: draft.text)
        guard !figures.isEmpty else { return (.noFigures, sources) }

        // Topics count too: an account's name can carry its card ending.
        let known = (sources.map(\.statement) + sources.map(\.topic) + [question])
            .flatMap { self.figures(in: $0) }
            .map(\.value)
        let candidates = derivedValues(from: known)

        let unmatched = figures.filter { figure in
            !matches(figure, known: known, derived: candidates)
        }
        guard unmatched.isEmpty else {
            return (.unverified(figures: unmatched.map(\.text)), sources)
        }
        return (.verified, sources)
    }

    // MARK: - Reading figures

    /// A number as written in text.
    struct Figure: Equatable, Sendable {
        /// The characters as written, e.g. `1,240.50`.
        let text: String
        /// The magnitude; signs and currency symbols are ignored.
        let value: Double
        /// Whether a `%` follows the number.
        let isPercentage: Bool
        /// Whether the number was written without decimals.
        let isWhole: Bool
    }

    /// Every number in `text`, in order.
    static func figures(in text: String) -> [Figure] {
        // A number glued to a letter (a fact ID such as F5, or Q3) is a
        // label, not a figure, so a number must start the text or follow
        // something that is neither a letter nor a digit.
        let pattern = /(?:^|[^\p{L}\d])(\d[\d,]*(?:\.\d+)?)(\s?%)?/
        return text.matches(of: pattern).compactMap { match in
            let written = String(match.output.1)
            let plain = written.replacing(",", with: "")
            guard let value = Double(plain) else { return nil }
            return Figure(
                text: written,
                value: value,
                isPercentage: match.output.2 != nil,
                isWhole: !plain.contains(".")
            )
        }
    }

    // MARK: - Matching

    /// Sums, differences and percentage ratios of each pair of known values.
    private static func derivedValues(from known: [Double]) -> (arithmetic: [Double], ratios: [Double]) {
        var arithmetic: [Double] = []
        var ratios: [Double] = []
        for (index, first) in known.enumerated() {
            for second in known[(index + 1)...] {
                arithmetic.append(first + second)
                arithmetic.append(abs(first - second))
                if second != 0 { ratios.append(first / second * 100) }
                if first != 0 { ratios.append(second / first * 100) }
            }
        }
        return (arithmetic, ratios)
    }

    private static func matches(
        _ figure: Figure,
        known: [Double],
        derived: (arithmetic: [Double], ratios: [Double])
    ) -> Bool {
        let pool = known + derived.arithmetic + (figure.isPercentage ? derived.ratios : [])
        return pool.contains { equals(figure, $0) }
    }

    /// Exact to the cent, or a whole-number rounding of the value.
    private static func equals(_ figure: Figure, _ value: Double) -> Bool {
        if abs(figure.value - value) <= tolerance { return true }
        guard figure.isWhole else {
            return abs(figure.value - (value * 10).rounded() / 10) <= tolerance
        }
        return figure.value == value.rounded() || figure.value == value.rounded(.down)
    }
}
