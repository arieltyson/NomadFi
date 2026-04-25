// DecisionAIIntakeViewModel.swift
// NomadFi
//
// Drives the Phase 9A Apple Intelligence intake sheet. Holds the
// scenario-input field, the interpreter availability state, the
// pending interpretation, the bounded clarification loop, and the
// editable review fields the user confirms before persistence.
//
// Honesty contract pinned in `DecisionAIIntakeTests`:
//
//   • Persistence happens *only* in `confirmAndSave(in:)`. The
//     interpreter never inserts records, the view model never
//     auto-confirms, and the sheet never silently moves an
//     interpretation onto disk.
//   • Editable review fields seed from the interpretation (and
//     from any clarifying answers) but are fully user-controlled —
//     typed edits win on save.
//   • Interpretation requests are async + cancellable. Tapping
//     "Interpret" while one is in flight is a no-op.
//
// Phase 9A follow-through (this slice):
//
//   • Missing-field computation is *kind-aware* and lives in
//     `DecisionDraftInterpretationCompleteness`. The interpreter
//     just extracts; this view model decides which gaps are worth
//     a clarifying question.
//   • The clarification flow is *bounded* via
//     `DecisionAIClarificationPlanner` (max
//     `DecisionAIClarificationPlan.maxQuestions`). The user can
//     skip the current question, skip the whole loop, or drop into
//     the typed form at any point — those affordances live on the
//     sheet, the view model just exposes the actions.

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
    /// Bounded clarifying-question loop. The associated value is
    /// the index of the question currently being answered (`0 ..<
    /// plan.count`). Plan itself lives on the view model so the
    /// sheet only renders the current question.
    case clarifying(index: Int)
    /// Interpretation (and any clarifying answers) succeeded.
    /// Review fields are editable; user must explicitly confirm
    /// before save.
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
    /// interpreter succeeds. Mutated by the clarification loop as
    /// the user answers each follow-up so the eventual review
    /// stage sees the latest combined value.
    private(set) var pendingInterpretation: DecisionDraftInterpretation?

    /// The bounded clarification plan derived from the current
    /// `pendingInterpretation`'s kind + completeness gap. `.none`
    /// (empty) when no clarification is needed; the sheet
    /// short-circuits to the review stage in that case.
    private(set) var clarificationPlan: DecisionAIClarificationPlan = .none

    /// Free-form text the user is typing into the *current*
    /// clarifying question. Bound by the sheet to a `TextField`,
    /// `Picker`, or numeric pad. Reset when the question advances.
    var clarificationDraftText: String = ""

    /// Currency picked for the *current* clarifying question when
    /// the question's `inputKind` is `.currency`. Defaults to USD
    /// so the picker has a stable initial selection.
    var clarificationDraftCurrency: CurrencyCode = .usd

    /// Kind picked for the *current* clarifying question when the
    /// question's `inputKind` is `.kind`. Defaults to the
    /// pending interpretation's current kind so the picker starts
    /// on a sensible value.
    var clarificationDraftKind: DecisionDraftKind = .other

    /// Kind-aware missing-field list derived from the latest
    /// interpretation via `DecisionDraftInterpretationCompleteness`.
    /// Surfaced to the review sheet so the user sees the same gaps
    /// the planner used. Empty when nothing is missing for the
    /// interpreted kind.
    var missingFields: [DecisionDraftInterpretationMissingField] {
        guard let interpretation = pendingInterpretation else { return [] }
        return DecisionDraftInterpretationCompleteness
            .missingFields(in: interpretation)
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
    /// false. After a successful interpretation the view model
    /// derives a kind-aware clarification plan; if any clarifying
    /// questions are needed the sheet enters the bounded
    /// `.clarifying` loop, otherwise it short-circuits to
    /// `.review`.
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
            applyDerivedClarificationPlan()
        case .failed(let reason):
            pendingInterpretation = nil
            clarificationPlan = .none
            stage = .failed(reason: reason)
        }
    }

    /// Recomputes `clarificationPlan` from the current
    /// `pendingInterpretation` and routes the sheet into the
    /// appropriate next stage. Centralised so every "we just
    /// updated the interpretation" path (initial interpret, after
    /// a clarifying answer) goes through the same rule.
    private func applyDerivedClarificationPlan() {
        guard let interpretation = pendingInterpretation else {
            clarificationPlan = .none
            stage = .review
            return
        }
        let missing = DecisionDraftInterpretationCompleteness
            .missingFields(in: interpretation)
        let plan = DecisionAIClarificationPlanner.plan(
            kind: interpretation.kind,
            missingFields: missing
        )
        clarificationPlan = plan
        if plan.isEmpty {
            stage = .review
        } else {
            seedClarificationDrafts(for: plan.questions[0])
            stage = .clarifying(index: 0)
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
        clarificationPlan = .none
    }

    /// Resets the model entirely. Called when the sheet is
    /// dismissed without save so a re-entry starts fresh.
    func reset() {
        scenarioText = ""
        pendingInterpretation = nil
        clarificationPlan = .none
        clarificationDraftText = ""
        clarificationDraftCurrency = .usd
        clarificationDraftKind = .other
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

    // MARK: - Clarification loop

    /// The clarifying question the sheet should currently render,
    /// or `nil` when the sheet is not in the `.clarifying` stage
    /// (or the index has run off the end of the plan).
    var currentClarifyingQuestion: DecisionAIClarifyingQuestion? {
        guard case let .clarifying(index) = stage else { return nil }
        guard clarificationPlan.questions.indices.contains(index) else { return nil }
        return clarificationPlan.questions[index]
    }

    /// Whether the current draft input is non-empty / valid enough
    /// to commit. Drives the Continue button's disabled state.
    var canSubmitClarificationAnswer: Bool {
        guard let question = currentClarifyingQuestion else { return false }
        switch question.inputKind {
        case .shortText, .amount:
            return !clarificationDraftText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        case .currency, .kind:
            // Picker controls always have a selected value.
            return true
        }
    }

    /// Folds the user's answer to the current question into the
    /// pending interpretation, advances to the next question, or —
    /// when this was the last question — recomputes the
    /// clarification plan in case kind changed mid-loop and
    /// transitions to `.review` if nothing else needs asking.
    func submitClarificationAnswer() {
        guard let question = currentClarifyingQuestion,
              case let .clarifying(index) = stage,
              let interpretation = pendingInterpretation
        else { return }

        let trimmed = clarificationDraftText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let updated = Self.applyAnswer(
            for: question,
            text: trimmed,
            currency: clarificationDraftCurrency,
            kind: clarificationDraftKind,
            to: interpretation
        )
        pendingInterpretation = updated
        seedReviewFields(from: updated)
        advanceClarification(after: index)
    }

    /// Skips the current question without recording an answer. The
    /// gap stays unresolved; the user can fill it on the review
    /// screen. Same advance rules as `submitClarificationAnswer`.
    func skipCurrentClarification() {
        guard case let .clarifying(index) = stage else { return }
        advanceClarification(after: index)
    }

    /// Skips every remaining clarifying question and jumps to the
    /// review stage. The interpretation is unchanged; remaining
    /// gaps surface verbatim on the review form.
    func skipAllClarification() {
        clarificationDraftText = ""
        stage = .review
    }

    // MARK: - Private — clarification mechanics

    /// Decides whether `index + 1` is still inside the plan. If
    /// yes, reseeds the draft inputs for the next question. If no,
    /// re-derives the plan from the now-updated interpretation
    /// (kind may have changed mid-loop) — empty plan transitions
    /// to `.review`, otherwise enters a fresh `.clarifying(0)`.
    private func advanceClarification(after index: Int) {
        let next = index + 1
        if next < clarificationPlan.count {
            seedClarificationDrafts(for: clarificationPlan.questions[next])
            stage = .clarifying(index: next)
        } else {
            // Plan exhausted. If the kind or other fields changed
            // along the way the new completeness check may either
            // close the loop entirely or surface a new (still
            // bounded) plan rooted in the updated interpretation.
            applyDerivedClarificationPlan()
        }
    }

    /// Pre-populates the clarification draft inputs for `question`
    /// from the pending interpretation so the user always sees a
    /// sensible starting value rather than an empty control.
    private func seedClarificationDrafts(
        for question: DecisionAIClarifyingQuestion
    ) {
        clarificationDraftText = ""
        clarificationDraftCurrency = pendingInterpretation?.currencyCode ?? reviewCurrencyCode
        clarificationDraftKind = pendingInterpretation?.kind ?? reviewKind

        switch question.field {
        case .amount:
            if let amount = pendingInterpretation?.amount {
                clarificationDraftText = Self.amountEditingText(for: amount)
            }
        case .merchantName:
            clarificationDraftText = pendingInterpretation?.merchantName ?? ""
        case .locationText:
            clarificationDraftText = pendingInterpretation?.locationText ?? ""
        case .timingText:
            clarificationDraftText = pendingInterpretation?.timingText ?? ""
        case .title:
            clarificationDraftText = pendingInterpretation?.title ?? ""
        case .currencyCode, .kind:
            break
        }
    }

    /// Pure helper — folds a single clarifying answer into the
    /// supplied interpretation, returning a new value-typed
    /// interpretation. Centralised so the apply rules stay easy to
    /// audit and so the view model stays a thin wrapper.
    private static func applyAnswer(
        for question: DecisionAIClarifyingQuestion,
        text: String,
        currency: CurrencyCode,
        kind: DecisionDraftKind,
        to interpretation: DecisionDraftInterpretation
    ) -> DecisionDraftInterpretation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedText: String? = trimmed.isEmpty ? nil : trimmed

        switch question.field {
        case .amount:
            return interpretation.with(amount: parseAmount(text))
        case .currencyCode:
            return interpretation.with(currencyCode: currency)
        case .merchantName:
            return interpretation.with(merchantName: resolvedText)
        case .locationText:
            return interpretation.with(locationText: resolvedText)
        case .timingText:
            return interpretation.with(timingText: resolvedText)
        case .title:
            return interpretation.with(title: resolvedText)
        case .kind:
            return interpretation.with(kind: kind)
        }
    }

    private static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let direct = Double(trimmed) { return direct }
        if let localeDecimal = Decimal(string: trimmed, locale: .current) {
            return NSDecimalNumber(decimal: localeDecimal).doubleValue
        }
        return nil
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
