// FoundationModelsDraftInterpreter.swift
// NomadFi
//
// Phase 9A — production interpreter that wraps Apple's
// `FoundationModels` framework. Wrapped in `#if canImport(...)`
// so the rest of the AI intake layer compiles on toolchains that
// don't ship Foundation Models, and so the build can fall back to
// `.foundationModelsUnavailable` cleanly.
//
// Design notes:
//
//   • We use guided generation into a `@Generable` Swift type
//     that mirrors the existing `DecisionDraftRecord` field shape.
//     The model never decides which card to use — it only
//     extracts structured *inputs*. The deterministic engines
//     downstream remain the source of truth.
//   • Availability is reported through Apple's own
//     `SystemLanguageModel.Availability` enum, mapped into our
//     `DecisionAIIntakeAvailability` so the UI doesn't couple to
//     Apple's enum cases.
//   • All prompt text and instructions are kept in this file so a
//     future review against Apple's docs can re-walk them in one
//     place. The instructions explicitly forbid recommendation,
//     "best", "verified", or "analyzed" language so the model's
//     output stays compatible with the copy-guard tests.

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Production interpreter backed by Apple's on-device system
/// language model. Constructed cheaply; the underlying session is
/// created lazily inside `interpret(...)` so a never-used intake
/// sheet never spins one up.
@available(iOS 26.0, *)
struct FoundationModelsDraftInterpreter: DecisionDraftInterpreter {

    /// Procedural instructions for the model. Pinned in code so a
    /// future audit re-walks them in one place. The model may
    /// extract structured inputs only — never produce a
    /// recommendation, "verified", "analyzed", or "best" string.
    private static let modelInstructions = """
    You extract structured inputs from a user's natural-language \
    decision scenario. You do not recommend a card, account, or \
    payment method. You do not generate financial, tax, or \
    investing advice. Avoid the words best, recommended, \
    verified, analyzed, or guaranteed.

    For each scenario, identify a likely decision kind \
    (purchase, travel, creditTiming, taxEducation, \
    investingEducation, or other), an optional short title, the \
    merchant or counterparty if mentioned, a city or short \
    location hint if mentioned (never a full address), an amount \
    if implied, the currency for that amount if mentioned, and a \
    short timing phrase if mentioned (do not parse it into a \
    date). Leave any field you cannot extract confidently as \
    null. Return an optional one-line confidenceNote only when a \
    field was inferred rather than directly extracted.
    """

    func availability() -> DecisionAIIntakeAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return Self.mapAvailability(reason)
        }
    }

    func interpret(scenarioText: String) async -> DecisionAIIntakeResult {
        let trimmed = scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failed(reason: "Add a scenario before requesting an interpretation.")
        }

        let session = LanguageModelSession(
            instructions: Self.modelInstructions
        )

        do {
            let response = try await session.respond(
                to: trimmed,
                generating: ScenarioExtraction.self
            )
            return .interpreted(response.content.toInterpretation(scenarioText: trimmed))
        } catch {
            return .failed(
                reason: "AI intake couldn't finish. Try again or capture the draft with the typed form. (\(error.localizedDescription))"
            )
        }
    }

    // MARK: - Availability mapping

    private static func mapAvailability(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> DecisionAIIntakeAvailability {
        switch reason {
        case .deviceNotEligible:
            return .unsupportedOnThisDevice
        case .appleIntelligenceNotEnabled:
            return .appleIntelligenceDisabled
        case .modelNotReady:
            return .modelNotReady
        @unknown default:
            return .unsupportedOnThisDevice
        }
    }
}

// MARK: - Guided-generation schema

/// `@Generable` Swift type the model populates via guided
/// generation. Optional fields stay optional so the model can
/// signal "not extracted" instead of guessing.
@available(iOS 26.0, *)
@Generable
private struct ScenarioExtraction {

    @Guide(description: "Decision kind. Choose exactly one of: purchase, travel, creditTiming, taxEducation, investingEducation, other.")
    var kind: String

    @Guide(description: "Short one-line title (under 60 characters). Null when no clean title can be extracted.")
    var title: String?

    @Guide(description: "Merchant or counterparty mentioned. Null when none.")
    var merchantName: String?

    @Guide(description: "City or short location hint. Never a full address. Null when none.")
    var locationText: String?

    @Guide(description: "Numeric amount if the scenario implied one. Null when none.")
    var amount: Double?

    @Guide(description: "Currency code (USD, CAD, EUR, GBP, TTD). Null when none.")
    var currencyCode: String?

    @Guide(description: "Short timing phrase in the user's words. Do not parse into a date. Null when none.")
    var timingText: String?

    @Guide(description: "Optional one-line factual note when a field was inferred rather than directly extracted. Null when nothing to flag.")
    var confidenceNote: String?

    /// Pure conversion into the value-layer interpretation type
    /// the rest of the intake layer consumes. Pulls in the
    /// scenario text the user pasted so downstream code never has
    /// to re-thread it.
    ///
    /// Phase 9A follow-through: the interpreter no longer computes
    /// `missingFields` on its own. That responsibility moved out to
    /// `DecisionDraftInterpretationCompleteness`, which applies
    /// kind-aware rules so the intake sheet only asks about gaps a
    /// downstream deterministic engine actually needs. The
    /// interpreter just *extracts*; the app decides what
    /// clarification is worth asking about.
    func toInterpretation(scenarioText: String) -> DecisionDraftInterpretation {
        let resolvedKind = DecisionDraftKind(rawValue: kind) ?? .other
        let resolvedCurrency = currencyCode.flatMap {
            CurrencyCode(rawValue: $0.uppercased())
        }

        return DecisionDraftInterpretation(
            kind: resolvedKind,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            scenarioText: scenarioText,
            merchantName: merchantName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            locationText: locationText?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            amount: amount,
            currencyCode: resolvedCurrency,
            timingText: timingText?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            notes: nil,
            missingFields: [],
            confidenceNote: confidenceNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

#else

/// Stub used on toolchains that don't ship Foundation Models.
/// Always reports unavailable so the typed form remains the
/// universal intake path.
struct FoundationModelsDraftInterpreter: DecisionDraftInterpreter {

    func availability() -> DecisionAIIntakeAvailability {
        .foundationModelsUnavailable
    }

    func interpret(scenarioText: String) async -> DecisionAIIntakeResult {
        .failed(
            reason: "AI-assisted intake isn't available in this build. Capture the draft with the typed form."
        )
    }
}

#endif
