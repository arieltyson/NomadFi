// CreditLimitReadinessItem.swift
// NomadFi
//
// A single check inside the credit-limit-increase readiness list.
// Each item maps to something NomadFi can actually verify on-device,
// *or* to an issuer-only fact the user must confirm themselves —
// both statuses are named explicitly so the UI never implies that
// the missing issuer facts are known.

import Foundation

/// Status of a single readiness check. The UI picks a colour + icon
/// off this enum, but the semantics stay on the value layer.
enum CreditLimitReadinessStatus: String, Sendable, Equatable, CaseIterable {

    /// NomadFi has evidence on file that the check passes.
    case met

    /// NomadFi has evidence on file and the check does not pass. The
    /// user has a clear action to take.
    case notMet

    /// NomadFi has no evidence either way. Used for data the user
    /// hasn't entered yet (e.g. credit limit missing).
    case missing

    /// The check depends on an issuer-side fact NomadFi can never
    /// verify on its own (income, payment history, account age,
    /// hard-inquiry policy, issuer eligibility). Always surfaced as
    /// a caveat — never flipped to `.met` by the engine.
    case issuerOnly

    // MARK: - Display

    /// Short label surfaced on the checklist row.
    var displayLabel: String {
        switch self {
        case .met: "On file"
        case .notMet: "Not yet"
        case .missing: "Not provided"
        case .issuerOnly: "Ask your issuer"
        }
    }

    /// VoiceOver phrasing. Never implies an approval guarantee.
    var accessibilityLabel: String {
        switch self {
        case .met: "Confirmed on file."
        case .notMet: "Not yet met. Review the detail for the next step."
        case .missing: "Not provided yet. Enter it in Settings."
        case .issuerOnly: "Issuer-only fact. Ask your card issuer to confirm."
        }
    }

    /// SF Symbol that pairs with the label so Differentiate-Without-
    /// Color users read the status correctly.
    var systemImage: String {
        switch self {
        case .met: "checkmark.seal"
        case .notMet: "exclamationmark.circle"
        case .missing: "questionmark.circle"
        case .issuerOnly: "person.crop.circle.badge.questionmark"
        }
    }
}

/// One row inside the readiness checklist for a card.
struct CreditLimitReadinessItem: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let status: CreditLimitReadinessStatus
}
