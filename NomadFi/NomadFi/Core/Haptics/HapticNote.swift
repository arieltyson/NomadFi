// HapticNote.swift
// NomadFi
//
// One sound-free "note" in a haptic score.

import Foundation

/// A single haptic event, described as plain values so scores can be
/// written, read and tested without Core Haptics.
struct HapticNote: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        /// A brief tap.
        case transient
        /// A sustained buzz, optionally fading to nothing by its end.
        case continuous(duration: TimeInterval, fadesOut: Bool)
    }

    let kind: Kind
    /// Seconds from the start of the score.
    let time: TimeInterval
    /// Strength, 0...1.
    let intensity: Float
    /// Character, from round and dull (0) to crisp and precise (1).
    let sharpness: Float

    static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> HapticNote {
        HapticNote(kind: .transient, time: time, intensity: intensity, sharpness: sharpness)
    }

    static func swell(
        at time: TimeInterval,
        for duration: TimeInterval,
        intensity: Float,
        sharpness: Float,
        fadesOut: Bool = false
    ) -> HapticNote {
        HapticNote(kind: .continuous(duration: duration, fadesOut: fadesOut), time: time, intensity: intensity, sharpness: sharpness)
    }

    /// When the note finishes.
    var end: TimeInterval {
        switch kind {
        case .transient: time
        case .continuous(let duration, _): time + duration
        }
    }
}
