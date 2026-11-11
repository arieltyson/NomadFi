import CoreHaptics
import Testing
@testable import NomadFi

struct HapticMotifTests {

    @Test(arguments: HapticMotif.allCases)
    func everyNoteIsInRangeAndInOrder(_ motif: HapticMotif) {
        let notes = motif.notes
        #expect(!notes.isEmpty)
        #expect(notes.map(\.time) == notes.map(\.time).sorted())
        #expect(notes.allSatisfy { (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) && $0.time >= 0 })
        #expect(motif.duration < 1, "Motifs stay short enough to feel like a single gesture")
    }

    @Test func arrivalTapsLandOnTheRevealBeats() {
        let taps = HapticMotif.arrival.notes.filter { $0.kind == .transient }.map(\.time)
        #expect(taps == [ArrivalCadence.globeLands, ArrivalCadence.firstLine, ArrivalCadence.secondLine])
    }

    @Test func theCoinQuickensAndFades() {
        let notes = HapticMotif.coinSettle.notes
        #expect(notes.map(\.time) == CoinCadence.edges)
        let gaps = zip(notes.dropFirst(), notes).map { $0.time - $1.time }
        #expect(gaps == gaps.sorted(by: >), "Each spin is quicker than the last")
        #expect(notes.map(\.intensity) == notes.map(\.intensity).sorted(by: >), "Each tap is softer than the last")
    }

    @Test(arguments: HapticMotif.allCases)
    func everyMotifBecomesACoreHapticsPattern(_ motif: HapticMotif) throws {
        _ = try HapticConductor.pattern(for: motif.notes)
    }
}
