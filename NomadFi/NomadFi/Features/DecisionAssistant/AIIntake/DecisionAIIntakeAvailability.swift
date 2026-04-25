// DecisionAIIntakeAvailability.swift
// NomadFi
//
// Discrete enum that names whether the on-device interpreter can
// run on the current device + OS + user-state combination. Lets
// the intake sheet render an honest unavailable explanation
// instead of pretending Apple Intelligence is everywhere.
//
// The cases mirror Apple Foundation Models' own availability
// reasons but stay small and stable so the UI does not couple to
// the underlying SDK enum.

import Foundation

/// Honest availability state for the on-device draft interpreter.
/// The intake sheet reads this and either offers the AI flow or
/// renders a calm "use the typed form instead" fallback.
enum DecisionAIIntakeAvailability: Sendable, Equatable, Hashable {

    /// Interpreter is ready to run on this device.
    case available

    /// Apple Intelligence is supported on this device but the
    /// system model isn't ready yet (e.g. assets still
    /// downloading). The intake sheet asks the user to try again
    /// later.
    case modelNotReady

    /// User has not enabled Apple Intelligence in Settings, or
    /// device-level Apple Intelligence is currently off. The
    /// intake sheet points the user at Settings without claiming
    /// to know exactly which toggle.
    case appleIntelligenceDisabled

    /// Device or OS does not support Apple Intelligence at all.
    /// The intake sheet hides the AI affordance entirely on this
    /// path — the typed form remains the universal intake.
    case unsupportedOnThisDevice

    /// Build was compiled without Foundation Models linked (e.g.
    /// older toolchain). The intake sheet renders the same calm
    /// unavailable explanation as `unsupportedOnThisDevice`.
    case foundationModelsUnavailable

    // MARK: - Display

    /// Whether the intake sheet should render the AI affordance
    /// in an actionable state.
    var isReadyToRun: Bool {
        if case .available = self { return true }
        return false
    }

    /// Short, factual explanation rendered on the intake sheet
    /// when the interpreter can't run. Procedural — never
    /// marketing.
    var unavailableHeadline: String? {
        switch self {
        case .available:
            return nil
        case .modelNotReady:
            return "Apple Intelligence is supported on this device, but the system model isn't ready yet."
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is off on this device or for NomadFi. Turn it on in Settings to use AI-assisted intake, or capture the draft with the typed form."
        case .unsupportedOnThisDevice:
            return "This device or OS doesn't support Apple Intelligence. Use the typed form to capture the draft."
        case .foundationModelsUnavailable:
            return "AI-assisted intake isn't available in this build. Use the typed form to capture the draft."
        }
    }
}
