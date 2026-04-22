// DecisionDraftFormViewModel.swift
// NomadFi
//
// Drives the capture sheet behind the Decision Assistant's
// "Gathered intelligence" flow. Keeps trimming, validation, amount
// parsing, and the SwiftData insert out of the view so both the
// Save-disabled state and the save payload are unit-testable.

import Foundation
import Observation
import OSLog
import SwiftData

/// Editable state for a new ``DecisionDraftRecord``.
///
/// The view binds to every `var` on this type directly. On save, the
/// view model trims strings, parses ``amountText``, stamps
/// timestamps, and inserts a fresh record into the provided
/// `ModelContext`. The view model stays UI-agnostic — it knows
/// nothing about sheets, focus, or tokens — so tests can exercise
/// the full save path without rendering.
@MainActor
@Observable
final class DecisionDraftFormViewModel {

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

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DecisionDraftForm"
    )

    // MARK: - Derived

    /// Trimmed scenario text — the single required field. Used by
    /// ``canSave`` and by ``save(into:)`` so the disabled state and
    /// the persisted payload can never drift apart.
    var trimmedScenarioText: String {
        scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether Save is allowed. NomadFi refuses to persist a draft
    /// whose scenario body is empty after trimming — a draft without
    /// a description is indistinguishable from an accidental tap.
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

    /// Persists the current inputs as a new ``DecisionDraftRecord``.
    ///
    /// Returns the inserted record so callers (tests or the view)
    /// can reference it; returns `nil` if the form is not in a
    /// saveable state. All string fields are trimmed before storage.
    @discardableResult
    func save(into modelContext: ModelContext) -> DecisionDraftRecord? {
        guard canSave else {
            Self.logger.debug("save called while canSave is false — refusing")
            return nil
        }

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
        do {
            try modelContext.save()
        } catch {
            Self.logger.error(
                "Failed to save decision draft: \(error.localizedDescription, privacy: .public)"
            )
        }
        return record
    }
}
