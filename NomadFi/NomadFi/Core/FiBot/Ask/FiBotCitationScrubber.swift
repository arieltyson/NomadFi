// FiBotCitationScrubber.swift
// NomadFi
//
// Keeps fact IDs out of the words a person reads.

import Foundation

/// Moves fact IDs the model wrote into its sentence ("based on F5") to
/// the citation list, where they belong.
///
/// The IDs are bookkeeping between the model and the verifier. Left in
/// the sentence they read as jargon, and their digits were mistaken for
/// figures that could not be checked.
enum FiBotCitationScrubber {

    /// `draft` with fact IDs removed from its text and added to its citations.
    static func scrub(_ draft: FiBotAnswerDraft) -> FiBotAnswerDraft {
        let mentioned = draft.text.matches(of: /\b[Ff](\d+)\b/).map { "F\($0.output.1)" }
        guard !mentioned.isEmpty else { return draft }

        let citation = /[\s,;:]*\(?\s*(?:(?:as\s+)?(?:based\s+on|according\s+to|from|per|see|in|using)\s+)?(?:facts?\s+)?\b[Ff]\d+\b(?:\s*(?:,\s*and|,|and|&)\s*(?:facts?\s+)?[Ff]\d+\b)*\s*\)?/
            .ignoresCase()
        var text = draft.text.replacing(citation, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        if let first = text.first, first.isLowercase {
            text.replaceSubrange(text.startIndex...text.startIndex, with: first.uppercased())
        }

        var ids = draft.citedFactIDs
        for id in mentioned where !ids.contains(id) { ids.append(id) }
        return FiBotAnswerDraft(text: text, citedFactIDs: ids)
    }

    /// `draft` ready to check and show: citations moved out of the
    /// sentence and any card-length number masked.
    static func prepare(_ draft: FiBotAnswerDraft) -> FiBotAnswerDraft {
        let scrubbed = scrub(draft)
        return FiBotAnswerDraft(
            text: SensitiveNumberRedactor.redactingAnswer(scrubbed.text),
            citedFactIDs: scrubbed.citedFactIDs
        )
    }
}
