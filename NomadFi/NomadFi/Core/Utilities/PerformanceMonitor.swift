// PerformanceMonitor.swift
// NomadFi
//
// Centralized signpost instrumentation for profiling key operations.
// Uses OSSignposter for zero-overhead measurement in Instruments.

import Foundation
import OSLog

/// Centralized performance monitoring using `OSSignposter`.
///
/// Provides structured signpost intervals for profiling in Instruments.
/// Each subsystem (network, SwiftData, image processing, view rendering)
/// has its own signpost category for independent analysis.
///
/// Usage:
/// ```swift
/// let interval = PerformanceMonitor.beginInterval(.network, name: "Fetch Rates")
/// // ... work ...
/// PerformanceMonitor.endInterval(.network, interval)
/// ```
///
/// In production builds, signposts compile to near-zero overhead.
/// Enable "Points of Interest" in Instruments to visualize intervals.
enum PerformanceMonitor {

    // MARK: - Subsystems

    /// Performance monitoring categories aligned with Instruments profiling.
    enum Subsystem: String {
        case network = "Network"
        case swiftData = "SwiftData"
        case imageProcessing = "ImageProcessing"
        case viewRendering = "ViewRendering"
        case insightEngine = "InsightEngine"
        case location = "Location"
        case export = "Export"
    }

    // MARK: - Signposters

    private static let signposters: [Subsystem: OSSignposter] = {
        var map: [Subsystem: OSSignposter] = [:]
        for subsystem in [Subsystem.network, .swiftData, .imageProcessing,
                          .viewRendering, .insightEngine, .location, .export] {
            map[subsystem] = OSSignposter(
                subsystem: "com.nomadfi.app",
                category: subsystem.rawValue
            )
        }
        return map
    }()

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Performance")

    // MARK: - Interval API

    /// Begins a named signpost interval for a given subsystem.
    ///
    /// Returns an opaque `SignpostInterval` that must be passed to
    /// ``endInterval(_:_:)`` when the operation completes.
    ///
    /// - Parameters:
    ///   - subsystem: The performance category to attribute this interval to.
    ///   - name: A static description of the operation being measured.
    /// - Returns: A signpost interval handle.
    static func beginInterval(
        _ subsystem: Subsystem,
        name: StaticString
    ) -> SignpostInterval {
        let signposter = signposters[subsystem]!
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        return SignpostInterval(
            subsystem: subsystem,
            name: name,
            id: id,
            state: state,
            startTime: ContinuousClock.now
        )
    }

    /// Ends a signpost interval and logs the elapsed duration.
    ///
    /// The duration is logged at `.debug` level for development builds
    /// and appears in the Instruments "Points of Interest" timeline.
    ///
    /// - Parameters:
    ///   - subsystem: The performance category (must match ``beginInterval``).
    ///   - interval: The interval handle returned by ``beginInterval``.
    static func endInterval(
        _ subsystem: Subsystem,
        _ interval: SignpostInterval
    ) {
        let signposter = signposters[subsystem]!
        signposter.endInterval(interval.name, interval.state)

        let elapsed = ContinuousClock.now - interval.startTime
        logger.debug(
            "\(subsystem.rawValue, privacy: .public) — \(interval.name, privacy: .public): \(elapsed, privacy: .public)"
        )
    }

    // MARK: - Convenience — Measured Closure

    /// Measures an async operation, wrapping it in a signpost interval.
    ///
    /// Automatically begins and ends the signpost around the closure,
    /// propagating the return value and any thrown errors.
    ///
    /// Uses `#isolation` to inherit the caller's actor context, allowing
    /// closures to safely capture actor-isolated state without crossing
    /// isolation boundaries.
    ///
    /// ```swift
    /// let rates = try await PerformanceMonitor.measure(.network, name: "Fetch Rates") {
    ///     try await service.fetchAllRates(for: currencies)
    /// }
    /// ```
    static func measure<T>(
        _ subsystem: Subsystem,
        name: StaticString,
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> T
    ) async rethrows -> T {
        let interval = beginInterval(subsystem, name: name)
        defer { endInterval(subsystem, interval) }
        return try await operation()
    }

    /// Measures a synchronous operation, wrapping it in a signpost interval.
    ///
    /// Uses `#isolation` to inherit the caller's actor context.
    static func measureSync<T>(
        _ subsystem: Subsystem,
        name: StaticString,
        isolation: isolated (any Actor)? = #isolation,
        operation: () throws -> T
    ) rethrows -> T {
        let interval = beginInterval(subsystem, name: name)
        defer { endInterval(subsystem, interval) }
        return try operation()
    }
}

// MARK: - Signpost Interval Handle

/// An opaque handle representing an active signpost interval.
///
/// Created by ``PerformanceMonitor/beginInterval(_:name:)`` and consumed
/// by ``PerformanceMonitor/endInterval(_:_:)``. Stores the start time
/// for duration logging alongside the OSSignposter state.
struct SignpostInterval: Sendable {
    let subsystem: PerformanceMonitor.Subsystem
    let name: StaticString
    let id: OSSignpostID
    let state: OSSignpostIntervalState
    let startTime: ContinuousClock.Instant
}
