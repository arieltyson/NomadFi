// ScriptedFiBotAnswerer.swift
// NomadFi
//
// A deterministic answerer for previews and tests.

import Foundation

/// Returns prepared drafts in order, so the verification loop and the
/// interface can be exercised without Apple Intelligence.
actor ScriptedFiBotAnswerer: FiBotAnswering {

    private var drafts: [FiBotAnswerDraft]
    private let status: FiBotAvailability

    /// Corrections received, one per redraft, for assertions.
    private(set) var corrections: [String] = []

    init(drafts: [FiBotAnswerDraft], availability: FiBotAvailability = .available) {
        self.drafts = drafts
        self.status = availability
    }

    nonisolated func availability() -> FiBotAvailability { status }

    func draft(
        question: String,
        sheet: FiBotFactSheet,
        previousExchange: FiBotExchange?,
        correction: String?
    ) async throws -> FiBotAnswerDraft {
        if let correction { corrections.append(correction) }
        guard !drafts.isEmpty else { throw FiBotAskError.failed }
        return drafts.count == 1 ? drafts[0] : drafts.removeFirst()
    }
}
