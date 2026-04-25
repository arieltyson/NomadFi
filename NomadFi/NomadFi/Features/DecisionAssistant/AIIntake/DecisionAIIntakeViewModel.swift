// DecisionAIIntakeViewModel.swift
// NomadFi
//
// Drives the Phase 9A Apple Intelligence intake sheet. Holds the
// scenario-input field, the interpreter availability state, the
// pending interpretation, and the editable review fields the user
// confirms before persistence.
//
// Honesty contract pinned in `DecisionAIIntakeTests`:
//
//   • Persistence happens *only* in `confirmAndSave(in:)`. The
//     interpreter never inserts records, the view model never
//     auto-confirms, and the sheet never silently moves an
//     interpretation onto disk.
//   • Editable review fields seed from the interpretation but are
//     fully user-controlled — typed edits win on save.
//   • Interpretation requests are async + cancellable. Tapping
//     "Interpret" while one is in flight is a no-op.

import Foundation
import Observation
import OSLog
import SwiftData

/// Stages of the intake sheet. The sheet renders different
/// content for each.
enum DecisionAIIntakeStage: Sendable, Equatable {
    /// Showing the scenario textfield. Available + supported devices
    /// also see the "Interpret" button.
    case capture
    /// Interpreter is running.
    case interpreting
    /// Interpretation succeeded. Review fields are editable; user
    /// must explicitly confirm before save.
    case review
    /// Interpretation failed. Sheet shows the error and lets the
    /// user retry or fall back to the typed form.
    case failed(reason: String)
}

@MainActor
@Observable
final class DecisionAIIntakeViewModel {

    // MARK: - Inputs

    /// Free-form scenario the user pastes / types. The intake
    /// sheet binds its `TextEditor` to this.
    var scenarioText: String = ""

    // MARK: - Editable review fields (seeded from interpretation)

    var reviewKind: DecisionDraftKind = .other
    var reviewTitle: String = ""
    var reviewMerchantName: String = ""
    var reviewLocationText: String = ""
    var reviewAmountText: String = ""
    var reviewCurrencyCode: CurrencyCode = .usd
    var reviewTimingText: String = ""
    var reviewNotes: String = ""

    // MARK: - State

    /// Current intake stage.
    private(set) var stage: DecisionAIIntakeStage = .capture

    /// Cached availability snapshot. Refreshed via
    /// `refreshAvailability()`.
    private(set) var availability: DecisionAIIntakeAvailability = .foundationModelsUnavailable

    /// The interpretation the user is reviewing. `nil` until the
    /// interpreter succeeds.
    private(set) var pendingInterpretation: DecisionDraftInterpretation?

    /// Missing fields surfaced to the review sheet so the user
    /// knows which gaps they're filling in.
    var missingFields: [DecisionDraftInterpretationMissingField] {
        pendingInterpretation?.missingFields ?? []
    }

    /// Optional one-line caveat from the interpreter. Rendered on
    /// the review sheet near the top.
    var confidenceNote: String? {
        pendingInterpretation?.confidenceNote
    }

    // MARK: - Dependencies

    private let interpreter: DecisionDraftInterpreter
    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionAIIntake"
    )

    // MARK: - Init

    init(interpreter: DecisionDraftInterpreter) {
        self.interpreter = interpreter
    }

    // MARK: - Lifecycle

    /// Refreshes the cached availability state. Call this on
    /// sheet appear so the UI stays in sync with Settings changes.
    func refreshAvailability() {
        availability = interpreter.availability()
    }

    // MARK: - Derived

    /// Whether the "Interpret" button should be enabled. False
    /// when the device can't run the model, when scenario text is
    /// blank, or when an interpretation is already in flight.
    var canInterpret: Bool {
        guard availability.isReadyToRun else { return false }
        if case .interpreting = stage { return false }
        return !scenarioText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    /// Trimmed scenario the persistence layer expects. Required
    /// to be non-empty before save.
    var trimmedScenarioText: String {
        scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the Save button on the review screen should be
    /// enabled. Mirrors the typed-form rule: scenario text must
    /// be non-empty after trimming.
    var canSave: Bool {
        !trimmedScenarioText.isEmpty
    }

    // MARK: - Actions

    /// Kicks off an interpretation. No-op when `canInterpret` is
    /// false.
    func interpret() async {
        guard canInterpret else { return }
        stage = .interpreting

        let result = await interpreter.interpret(
            scenarioText: trimmedScenarioText
        )

        switch result {
        case .interpreted(let interpretation):
            pendingInterpretation = interpretation
            seedReviewFields(from: interpretation)
            stage = .review
        case .failed(let reason):
            pendingInterpretation = nil
            stage = .failed(reason: reason)
        }
    }

    /// Persists the user-confirmed review fields as a fresh
    /// `DecisionDraftRecord` and returns it. Returns `nil` if the
    /// form is not in a saveable state (defence in depth — the UI
    /// disables the button via `canSave`).
    @discardableResult
    func confirmAndSave(
        in modelContext: ModelContext,
        now: Date = .now
    ) -> DecisionDraftRecord? {
        guard canSave else {
            Self.logger.debug("confirmAndSave called while canSave is false — refusing")
            return nil
        }
        // Build the *final* interpretation from the editable
        // review fields so user edits always win on save.
        let confirmed = DecisionDraftInterpretation(
            kind: reviewKind,
            title: reviewTitle.nonEmptyTrimmed,
            scenarioText: trimmedScenarioText,
            merchantName: reviewMerchantName.nonEmptyTrimmed,
            locationText: reviewLocationText.nonEmptyTrimmed,
            amount: parseAmount(reviewAmountText),
            currencyCode: reviewCurrencyCode,
            timingText: reviewTimingText.nonEmptyTrimmed,
            notes: reviewNotes.nonEmptyTrimmed,
            missingFields: [],
            confidenceNote: nil
        )

        let record = DecisionDraftInterpretationMapper.record(
            from: confirmed,
            now: now
        )
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            Self.logger.error(
                "Failed to insert AI-intake draft: \(error.localizedDescription, privacy: .public)"
            )
        }
        return record
    }

    /// Drops back to the capture stage so the user can edit the
    /// scenario text and try again.
    func backToCapture() {
        stage = .capture
        pendingInterpretation = nil
    }

    /// Resets the model entirely. Called when the sheet is
    /// dismissed without save so a re-entry starts fresh.
    func reset() {
        scenarioText = ""
        pendingInterpretation = nil
        stage = .capture
        reviewKind = .other
        reviewTitle = ""
        reviewMerchantName = ""
        reviewLocationText = ""
        reviewAmountText = ""
        reviewCurrencyCode = .usd
        reviewTimingText = ""
        reviewNotes = ""
    }

    // MARK: - Private

    private func seedReviewFields(
        from interpretation: DecisionDraftInterpretation
    ) {
        reviewKind = interpretation.kind
        reviewTitle = interpretation.title ?? ""
        reviewMerchantName = interpretation.merchantName ?? ""
        reviewLocationText = interpretation.locationText ?? ""
        reviewAmountText = Self.amountEditingText(for: interpretation.amount)
        reviewCurrencyCode = interpretation.currencyCode ?? .usd
        reviewTimingText = interpretation.timingText ?? ""
        reviewNotes = interpretation.notes ?? ""
    }

    private func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let direct = Double(trimmed) { return direct }
        if let localeDecimal = Decimal(string: trimmed, locale: .current) {
            return NSDecimalNumber(decimal: localeDecimal).doubleValue
        }
        return nil
    }

    private static func amountEditingText(for amount: Double?) -> String {
        guard let amount else { return "" }
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(amount))
        }
        return String(amount)
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
