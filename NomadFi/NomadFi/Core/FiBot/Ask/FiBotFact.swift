// FiBotFact.swift
// NomadFi
//
// One statement about the user's money that NomadFi computed itself.

import Foundation

/// A single, deterministic statement about the user's finances.
///
/// Facts are the only ground truth Ask FiBot may use. They are built
/// on this device from SwiftData by ``FiBotFactSheetBuilder``, handed
/// to the on-device model, and used afterwards by
/// ``FiBotFigureVerifier`` to check every figure the model wrote.
struct FiBotFact: Identifiable, Hashable, Sendable {

    /// Short citation key such as `F3`, unique within one sheet.
    let id: String

    /// What the fact is about, for the Sources list (e.g. "Spending this month").
    let topic: String

    /// The statement itself, with figures written in a locale-neutral
    /// form (e.g. `CAD 1240.50`) so the verifier can read them back.
    let statement: String

    /// The line given to the model: `[F3] Spending this month: CAD 1240.50`.
    var promptLine: String { "[\(id)] \(topic): \(statement)" }
}
