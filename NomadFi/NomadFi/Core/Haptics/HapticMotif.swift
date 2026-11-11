// HapticMotif.swift
// NomadFi
//
// NomadFi's hand-written haptic scores. Each is paired with an animation
// that reads its timing from the same constants, so touch and motion land
// on the same frame.

import Foundation

/// A short, named haptic score with its own cadence.
enum HapticMotif: CaseIterable, Sendable {

    /// The welcome screen settling in: a low swell as the globe drifts
    /// down, a landing thud, then one tick per headline line.
    case arrival
    /// Choosing a country: a hard stamp and the softer settle of ink.
    case stamp
    /// Letting go of a choice: one soft, dull tap.
    case release
    /// Choosing a currency: a coin spinning down, its taps quickening
    /// and fading as it settles.
    case coinSettle
    /// A short double tap that says "keep holding".
    case nudge
    /// Finishing setup: three rising taps and a fading bloom.
    case bloom

    var notes: [HapticNote] {
        switch self {
        case .arrival:
            [
                .swell(at: 0, for: ArrivalCadence.globeLands, intensity: 0.35, sharpness: 0.1),
                .tap(at: ArrivalCadence.globeLands, intensity: 0.85, sharpness: 0.5),
                .tap(at: ArrivalCadence.firstLine, intensity: 0.45, sharpness: 0.8),
                .tap(at: ArrivalCadence.secondLine, intensity: 0.55, sharpness: 0.85),
            ]
        case .stamp:
            [
                .tap(at: 0, intensity: 1, sharpness: 0.85),
                .tap(at: StampCadence.settle, intensity: 0.35, sharpness: 0.15),
            ]
        case .release:
            [.tap(at: 0, intensity: 0.3, sharpness: 0.2)]
        case .coinSettle:
            CoinCadence.edges.enumerated().map { index, time in
                let fade = Float(index) / Float(CoinCadence.edges.count)
                return .tap(at: time, intensity: 0.8 - 0.6 * fade, sharpness: 0.9 - 0.3 * fade)
            }
        case .nudge:
            [
                .tap(at: 0, intensity: 0.4, sharpness: 0.5),
                .tap(at: 0.09, intensity: 0.4, sharpness: 0.5),
            ]
        case .bloom:
            [
                .tap(at: 0, intensity: 0.6, sharpness: 0.4),
                .tap(at: 0.06, intensity: 0.8, sharpness: 0.6),
                .tap(at: BloomCadence.burst, intensity: 1, sharpness: 0.9),
                .swell(at: BloomCadence.burst, for: BloomCadence.fade, intensity: 0.6, sharpness: 0.3, fadesOut: true),
            ]
        }
    }

    /// When the last note ends.
    var duration: TimeInterval { notes.map(\.end).max() ?? 0 }
}

/// Timing shared by the welcome screen's reveal and ``HapticMotif/arrival``.
enum ArrivalCadence {
    static let globeLands: TimeInterval = 0.45
    static let firstLine: TimeInterval = 0.75
    static let secondLine: TimeInterval = 0.95
    static let details: TimeInterval = 1.2
}

/// Timing shared by the country stamp animation and ``HapticMotif/stamp``.
enum StampCadence {
    /// When the flag hits hardest.
    static let impact: TimeInterval = 0.08
    /// The rebound below rest after the hit.
    static let rebound: TimeInterval = 0.1
    /// When the ink settles after the hit.
    static let settle: TimeInterval = 0.07
    /// The whole stamp, from press to rest.
    static let total: TimeInterval = 0.45
}

/// Timing shared by the currency coin flip and ``HapticMotif/coinSettle``.
/// Each time is a moment the spinning sign shows its edge.
enum CoinCadence {
    static let edges: [TimeInterval] = [0, 0.11, 0.2, 0.27, 0.32, 0.355]
    /// One full turn per edge pair, slowing to rest.
    static let total: TimeInterval = 0.42
}

/// Timing shared by the hold-to-begin burst and ``HapticMotif/bloom``.
enum BloomCadence {
    /// How long the button must be held.
    static let hold: TimeInterval = 0.9
    /// When the burst peaks after the hold completes.
    static let burst: TimeInterval = 0.12
    /// How long the bloom fades.
    static let fade: TimeInterval = 0.5
}
