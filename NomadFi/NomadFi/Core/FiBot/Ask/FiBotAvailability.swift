// FiBotAvailability.swift
// NomadFi
//
// Whether the on-device model can answer right now.

import Foundation

/// Whether Ask FiBot can run on this device, and if not, why.
enum FiBotAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    /// A one-line explanation for each unavailable state.
    var message: LocalizedStringResource? {
        switch self {
        case .available: nil
        case .deviceNotEligible: "Ask FiBot needs an iPhone that supports Apple Intelligence."
        case .appleIntelligenceNotEnabled: "Turn on Apple Intelligence in Settings to ask FiBot."
        case .modelNotReady: "Apple Intelligence is still getting ready. Try again soon."
        }
    }
}
