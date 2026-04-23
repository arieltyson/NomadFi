// TaxEducationQuizOption.swift
// NomadFi
//
// Single answer choice for a `TaxEducationQuizQuestion`. Pure
// value type — no runtime state, no correctness flag here
// (the question owns `correctOptionID` so ordering and display
// stay decoupled from scoring).

import Foundation

struct TaxEducationQuizOption: Sendable, Equatable, Identifiable, Hashable {

    /// Stable identifier — used by the scorer and by SwiftUI's
    /// `ForEach`. Matches `correctOptionID` on the owning question
    /// for the correct answer.
    let id: String

    /// Short, scannable option text shown in the quiz UI.
    let text: String
}
