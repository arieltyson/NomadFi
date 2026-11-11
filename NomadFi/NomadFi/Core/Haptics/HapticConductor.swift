// HapticConductor.swift
// NomadFi
//
// Plays HapticMotif scores on the Taptic Engine with Core Haptics.

import CoreHaptics
import Foundation
import OSLog
import SwiftUI

/// Owns the Core Haptics engine and plays NomadFi's motifs.
///
/// The engine starts lazily, restarts itself after the system resets it,
/// and shuts down when idle. On hardware without haptics every call does
/// nothing, so callers never need to check.
@MainActor
final class HapticConductor {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Haptics")

    private var engine: CHHapticEngine?
    private var holdPlayer: CHHapticAdvancedPatternPlayer?
    private let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// Plays a motif from the start.
    func play(_ motif: HapticMotif) {
        guard let engine = runningEngine() else { return }
        do {
            try engine.makePlayer(with: Self.pattern(for: motif.notes)).start(atTime: CHHapticTimeImmediate)
        } catch {
            Self.logger.error("Could not play motif: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Starts the hold-to-begin rumble, silent until ``updateHold(progress:)``.
    func beginHold() {
        guard let engine = runningEngine() else { return }
        endHold()
        do {
            let rumble = HapticNote.swell(at: 0, for: BloomCadence.hold * 4, intensity: 1, sharpness: 0.25)
            let player = try engine.makeAdvancedPlayer(with: Self.pattern(for: [rumble]))
            try player.sendParameters([Self.intensity(0)], atTime: CHHapticTimeImmediate)
            try player.start(atTime: CHHapticTimeImmediate)
            holdPlayer = player
        } catch {
            Self.logger.error("Could not start hold: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Raises the rumble with the hold's progress, so it swells as the
    /// button fills.
    func updateHold(progress: Double) {
        let eased = Float(progress * progress)
        try? holdPlayer?.sendParameters([Self.intensity(0.15 + 0.85 * eased)], atTime: CHHapticTimeImmediate)
    }

    /// Stops the rumble.
    func endHold() {
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
    }

    // MARK: - Engine

    private func runningEngine() -> CHHapticEngine? {
        guard isSupported else { return nil }
        if engine == nil {
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                engine.resetHandler = { [weak self] in
                    Task { @MainActor in try? self?.engine?.start() }
                }
                self.engine = engine
            } catch {
                Self.logger.error("Haptic engine unavailable: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        do {
            try engine?.start()
        } catch {
            Self.logger.error("Haptic engine failed to start: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        return engine
    }

    // MARK: - Patterns

    nonisolated static func pattern(for notes: [HapticNote]) throws -> CHHapticPattern {
        var curves: [CHHapticParameterCurve] = []
        let events = notes.map { note in
            let parameters = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: note.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: note.sharpness),
            ]
            switch note.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: note.time)
            case .continuous(let duration, let fadesOut):
                if fadesOut {
                    curves.append(CHHapticParameterCurve(
                        parameterID: .hapticIntensityControl,
                        controlPoints: [
                            .init(relativeTime: 0, value: 1),
                            .init(relativeTime: duration, value: 0),
                        ],
                        relativeTime: note.time
                    ))
                }
                return CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: note.time, duration: duration)
            }
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    private nonisolated static func intensity(_ value: Float) -> CHHapticDynamicParameter {
        CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: value, relativeTime: 0)
    }
}

extension EnvironmentValues {
    /// The haptic conductor for the current flow, if it plays custom motifs.
    @Entry var hapticConductor: HapticConductor? = nil
}
