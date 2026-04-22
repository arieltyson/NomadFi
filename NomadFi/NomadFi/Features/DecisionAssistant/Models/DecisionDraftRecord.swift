// DecisionDraftRecord.swift
// NomadFi
//
// Persisted, on-device record of a user-captured decision draft.
// Drafts are raw user-provided context — not recommendations. No
// field on this model is ever produced by a language model or
// inferred from generic AI. Every value is either typed directly by
// the user or a `.now` timestamp stamped at save.
//
// CloudKit-safe by construction:
//   - No `@Attribute(.unique)` — scenario uniqueness is enforced in
//     application code, not in the schema.
//   - Every stored property has a default or is optional.
//   - No relationships — the record is self-contained so future
//     sync migrations don't have to walk a graph.
//
// Privacy guardrails (enforced by the capture form, not this file):
//   - No account numbers, card numbers, SSNs, SINs, or full street
//     addresses. The `locationText` and `notes` fields are short,
//     user-written strings meant for city/context and free notes,
//     not for credentials or identifiers.
//   - Drafts never flow to a remote server; NomadFi has none.

import Foundation
import SwiftData

/// On-device decision-draft capture. One record per draft.
///
/// Rendered by ``DecisionDraftRow`` in the Decision Assistant's
/// "Gathered intelligence" section. Marked
/// ``DecisionDraftStatus/needsEngine`` until a deterministic engine
/// covers the draft's kind — never auto-analyzed by an LLM.
@Model
final class DecisionDraftRecord {

    // MARK: - Identity

    /// Stable per-draft identifier. UUID so the form and detail
    /// sheets can reference a draft safely even when a relationship
    /// layer is added later. Not `.unique`-annotated — CloudKit
    /// synced stores reject unique attributes.
    var draftID: UUID = UUID()

    // MARK: - User-provided content

    /// Optional short title the user can give the draft. Falls back
    /// to the first line of ``scenarioText`` in the row renderer
    /// when empty.
    var title: String = ""

    /// The user's description of the scenario, in their own words.
    /// Expected to be a paragraph or two — the capture form uses a
    /// `TextEditor` for this field so it can grow.
    var scenarioText: String = ""

    /// Raw value of ``DecisionDraftKind``. Stored as a String so the
    /// SwiftData schema is CloudKit-friendly (no enum migrations).
    var kindRawValue: String = DecisionDraftKind.purchase.rawValue

    /// Merchant or counterparty name, if applicable.
    var merchantName: String = ""

    /// Freeform location hint — city, country, or a short phrase
    /// like "Airbnb in San Francisco". Intentionally not a full
    /// address; the capture form enforces length through Dynamic
    /// Type, not business rules.
    var locationText: String = ""

    /// Optional monetary amount the user wants NomadFi to keep in
    /// mind. Nil when the draft has no numeric anchor.
    var amount: Double?

    /// Raw value of ``CurrencyCode``. Defaults to USD so the amount
    /// field always has a valid currency attached.
    var currencyCodeRawValue: String = CurrencyCode.usd.rawValue

    /// When the decision needs to be made, in the user's own words
    /// ("by Friday", "before Amazon ships", etc.). Deliberately
    /// textual — NomadFi does not parse this into a Date yet.
    var timingText: String = ""

    /// Extra notes the user wants attached. Free-form, optional.
    var notes: String = ""

    // MARK: - Lifecycle

    /// Raw value of ``DecisionDraftStatus``. Always starts at
    /// `.needsEngine` — NomadFi never promotes a draft to "analyzed"
    /// automatically.
    var statusRawValue: String = DecisionDraftStatus.needsEngine.rawValue

    /// Stamped at insertion time. Never mutated after.
    var createdAt: Date = Date.now

    /// Refreshed every time the user edits the draft or archives it,
    /// so the UI can sort by most recent activity.
    var updatedAt: Date = Date.now

    // MARK: - Init

    init(
        draftID: UUID = UUID(),
        title: String = "",
        scenarioText: String = "",
        kind: DecisionDraftKind = .purchase,
        merchantName: String = "",
        locationText: String = "",
        amount: Double? = nil,
        currencyCode: CurrencyCode = .usd,
        timingText: String = "",
        notes: String = "",
        status: DecisionDraftStatus = .needsEngine,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.draftID = draftID
        self.title = title
        self.scenarioText = scenarioText
        self.kindRawValue = kind.rawValue
        self.merchantName = merchantName
        self.locationText = locationText
        self.amount = amount
        self.currencyCodeRawValue = currencyCode.rawValue
        self.timingText = timingText
        self.notes = notes
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Derived

extension DecisionDraftRecord {

    /// Typed ``DecisionDraftKind`` view over ``kindRawValue``, with a
    /// safe fallback to `.other` so an unknown raw string never
    /// crashes the UI.
    var kind: DecisionDraftKind {
        DecisionDraftKind(rawValue: kindRawValue) ?? .other
    }

    /// Typed ``DecisionDraftStatus`` view over ``statusRawValue``.
    var status: DecisionDraftStatus {
        DecisionDraftStatus(rawValue: statusRawValue) ?? .needsEngine
    }

    /// Typed ``CurrencyCode`` view over ``currencyCodeRawValue``.
    var currencyCode: CurrencyCode {
        CurrencyCode(rawValue: currencyCodeRawValue) ?? .usd
    }

    /// Title used in row / detail surfaces — falls back to the first
    /// non-empty line of ``scenarioText`` when the explicit title is
    /// blank so even minimalist captures look presentable.
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let firstLine = scenarioText
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces)
        return firstLine?.isEmpty == false ? firstLine! : "Untitled draft"
    }
}
