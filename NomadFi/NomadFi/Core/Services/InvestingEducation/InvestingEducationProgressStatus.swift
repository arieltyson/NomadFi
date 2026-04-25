// InvestingEducationProgressStatus.swift
// NomadFi
//
// Tri-state lesson / checklist-item status. Two-state in 8A
// (`.notStarted` ↔ `.completed`); `.inProgress` reserved for a
// future quiz or guided-walkthrough layer.

import Foundation

enum InvestingEducationProgressStatus: String, Sendable, Equatable, Hashable, CaseIterable {
    case notStarted
    case inProgress
    case completed

    /// Tolerant parser so persisted records that hold an unknown
    /// raw value (e.g. from a future `inProgress` schema being
    /// downgraded) collapse to `.notStarted` rather than refusing
    /// to display.
    static func from(rawValue: String) -> InvestingEducationProgressStatus {
        InvestingEducationProgressStatus(rawValue: rawValue) ?? .notStarted
    }
}
