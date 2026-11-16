import Foundation

/// One part of a whole as the Spending charts and rows draw it.
struct SpendingChartSlice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let total: Double
    /// The slice's place among the ranked slices, which picks its color;
    /// `nil` for "Other", which is always drawn in the quiet color.
    let colorRank: Int?
    /// Its part of the whole, from 0 to 1.
    let share: Double
}
