// DecisionDraftFormViewModel.swift
// NomadFi
//
// Drives the capture and edit sheets behind the Decision Assistant's
// "Gathered intelligence" flow. Keeps trimming, validation, amount
// parsing, and the SwiftData insert / update out of the view so both
// the Save-disabled state and the save payload are unit-testable.
//
// One view model type serves both modes — creating a new draft and
// editing an existing one — so validation and trimming logic never
// fork between call sites. The mode is chosen at init time and the
// view binds to the same properties regardless.

import Foundation
import Observation
import OSLog
import SwiftData

/// Editable state for a ``DecisionDraftRecord``.
///
/// Initialised with `init()` to capture a new draft, or
/// `init(editing:)` to edit an existing one. On save, the view model
/// trims strings, parses ``amountText``, stamps `updatedAt`, and
/// either inserts a fresh record or mutates the existing one in
/// place. The view model stays UI-agnostic — it knows nothing about
/// sheets, focus, or tokens — so tests exercise the full save path
/// without rendering.
@MainActor
@Observable
final class DecisionDraftFormViewModel {

    // MARK: - Mode

    /// Form mode. `create` inserts a new record on save; `edit`
    /// mutates the captured reference, preserving `createdAt`.
    enum Mode {
        case create
        case edit(DecisionDraftRecord)

        /// Screen title shown in the form navigation bar.
        var navigationTitle: String {
            switch self {
            case .create: "Capture decision"
            case .edit: "Edit draft"
            }
        }

        /// Whether this mode represents editing an existing draft.
        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    // MARK: - Inputs

    var title: String = ""
    var scenarioText: String = ""
    var kind: DecisionDraftKind = .purchase
    var merchantName: String = ""
    var locationText: String = ""
    var amountText: String = ""
    var currencyCode: CurrencyCode = .usd
    var timingText: String = ""
    var notes: String = ""

    /// Current form mode. Set at init; read by the view for titles
    /// and by `save(into:)` to decide between insert and update.
    let mode: Mode

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionDraftForm"
    )

    // MARK: - Init

    /// Starts a new draft with NomadFi's defaults.
    init() {
        self.mode = .create
    }

    /// Opens the form pre-populated with an existing draft's fields.
    /// Save will mutate `record` in place.
    init(editing record: DecisionDraftRecord) {
        self.mode = .edit(record)
        self.title = record.title
        self.scenarioText = record.scenarioText
        self.kind = record.kind
        self.merchantName = record.merchantName
        self.locationText = record.locationText
        self.amountText = Self.amountEditingText(for: record.amount)
        self.currencyCode = record.currencyCode
        self.timingText = record.timingText
        self.notes = record.notes
    }

    // MARK: - Derived

    /// Trimmed scenario text — the single required field. Used by
    /// ``canSave`` and by ``save(into:)`` so the disabled state and
    /// the persisted payload can never drift apart.
    var trimmedScenarioText: String {
        scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether Save is allowed. NomadFi refuses to persist a draft
    /// whose scenario body is empty after trimming — applies in both
    /// create and edit modes so edits can never erase a draft's body
    /// through the form.
    var canSave: Bool {
        !trimmedScenarioText.isEmpty
    }

    /// Parsed monetary amount, or `nil` when the user left the field
    /// blank. Accepts either a raw decimal ("25.50") or a locale-aware
    /// format ("25,50") without imposing a locale on the user.
    var parsedAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let direct = Double(trimmed) {
            return direct
        }

        if let localeDecimal = Decimal(string: trimmed, locale: .current) {
            return NSDecimalNumber(decimal: localeDecimal).doubleValue
        }

        return nil
    }

    // MARK: - Save

    /// Persists the current inputs.
    ///
    /// In `.create` mode: inserts a new ``DecisionDraftRecord`` and
    /// returns it. In `.edit` mode: mutates the referenced record in
    /// place, stamps `updatedAt`, and returns the same instance.
    /// Returns `nil` when the form is not in a saveable state.
    @discardableResult
    func save(into modelContext: ModelContext) -> DecisionDraftRecord? {
        guard canSave else {
            Self.logger.debug("save called while canSave is false — refusing")
            return nil
        }

        switch mode {
        case .create:
            return insertNewDraft(into: modelContext)
        case .edit(let record):
            return updateExistingDraft(record, in: modelContext)
        }
    }

    // MARK: - Private

    private func insertNewDraft(
        into modelContext: ModelContext
    ) -> DecisionDraftRecord {
        let now = Date.now
        let record = DecisionDraftRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            scenarioText: trimmedScenarioText,
            kind: kind,
            merchantName: merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationText: locationText.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: parsedAmount,
            currencyCode: currencyCode,
            timingText: timingText.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .needsEngine,
            createdAt: now,
            updatedAt: now
        )

        modelContext.insert(record)
        persist(modelContext, action: "insert")
        return record
    }

    private func updateExistingDraft(
        _ record: DecisionDraftRecord,
        in modelContext: ModelContext
    ) -> DecisionDraftRecord {
        // createdAt is deliberately untouched — edits must not reset
        // the original capture moment. statusRawValue is untouched so
        // editing an archived draft doesn't unarchive it as a side
        // effect.
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.scenarioText = trimmedScenarioText
        record.kindRawValue = kind.rawValue
        record.merchantName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        record.locationText = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        record.amount = parsedAmount
        record.currencyCodeRawValue = currencyCode.rawValue
        record.timingText = timingText.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.updatedAt = Date.now

        persist(modelContext, action: "update")
        return record
    }

    private func persist(
        _ modelContext: ModelContext,
        action: String
    ) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error(
                "Failed to \(action, privacy: .public) decision draft: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Formats a stored ``DecisionDraftRecord/amount`` back into the
    /// text the `.decimalPad` field expects. Strips the trailing
    /// `.0` on whole numbers so editing an amount of `100` shows
    /// "100" rather than "100.0".
    private static func amountEditingText(for amount: Double?) -> String {
        guard let amount else { return "" }
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(amount))
        }
        return String(amount)
    }
}
