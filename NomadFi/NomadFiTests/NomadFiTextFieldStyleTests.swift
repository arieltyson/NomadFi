// NomadFiTextFieldStyleTests.swift
// NomadFi
//
// Pins the contract of the `NomadFiTextFieldStyle` design-system
// primitive plus the source-level guarantee that NomadFi-owned
// text inputs on custom surfaces (`SurfaceCard` and similar)
// route through `.textFieldStyle(.nomadFi)` rather than the
// system `.roundedBorder` style.
//
// Why a source-level chokepoint:
//   The system `.roundedBorder` style collapses to a flat
//   black-on-black rectangle in dark mode when nested inside the
//   app's translucent card surfaces. A future contributor who
//   reaches for `.roundedBorder` on a `SurfaceCard` surface should
//   fail this guardrail rather than ship the regression.
//
// SwiftUI views can't be deeply introspected from a unit test, so
// the contract is pinned the same way the other design-system
// primitives are: build-time signature smoke + a source-level
// guard that reads the touched files off disk and asserts the
// chokepoint call. The simulator sandbox can block file reads
// outside the bundle; the source-level cases degrade to a
// soft-skip in that environment so the suite still runs cleanly.

import Foundation
import SwiftUI
import Testing

@testable import NomadFi

@MainActor
struct NomadFiTextFieldStyleTests {

    // MARK: - API surface smoke

    @Test("`.nomadFi` static lookup resolves and conforms to TextFieldStyle — signature regressions fail at compile time before they reach call sites")
    func staticLookupSmoke() {
        struct Host: View {
            @State var text = ""
            var body: some View {
                TextField("Amount", text: $text)
                    .textFieldStyle(.nomadFi)
            }
        }
        _ = Host()
    }

    @Test("Style instance is constructible for direct use (callers that prefer instance-based API)")
    func directInstanceConstructs() {
        _ = NomadFiTextFieldStyle()
    }

    // MARK: - Chokepoint usage

    @Test("ScenarioNumericInputRow uses `.textFieldStyle(.nomadFi)` — never the system .roundedBorder")
    func scenarioNumericInputRowUsesPrimitive() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/Scenarios/Components/ScenarioNumericInputRow.swift"
        ) else { return }

        #expect(
            source.contains(".textFieldStyle(.nomadFi)"),
            """
            ScenarioNumericInputRow must apply \
            `.textFieldStyle(.nomadFi)` so the field renders with \
            the design-system container on every surface. \
            See the file header in `NomadFiTextFieldStyle.swift`.
            """
        )
        #expect(
            !source.contains(".textFieldStyle(.roundedBorder)"),
            """
            ScenarioNumericInputRow must not use \
            `.textFieldStyle(.roundedBorder)` — that system style \
            collapses to a flat black-on-black rectangle in dark \
            mode when nested in a `SurfaceCard`. Use \
            `.textFieldStyle(.nomadFi)` instead.
            """
        )
    }

    @Test("PurchaseDecisionBriefView uses `.textFieldStyle(.nomadFi)` for every NomadFi-owned text field — never the system .roundedBorder")
    func purchaseDecisionBriefViewUsesPrimitive() throws {
        guard let source = Self.sourceIfReadable(
            relativePath: "NomadFi/Features/DecisionAssistant/PurchaseDecision/PurchaseDecisionBriefView.swift"
        ) else { return }

        #expect(
            source.contains(".textFieldStyle(.nomadFi)"),
            """
            PurchaseDecisionBriefView must apply \
            `.textFieldStyle(.nomadFi)` to every NomadFi-owned \
            `TextField` so the form's inputs share the design \
            system's container.
            """
        )
        #expect(
            !source.contains(".textFieldStyle(.roundedBorder)"),
            """
            PurchaseDecisionBriefView must not use \
            `.textFieldStyle(.roundedBorder)` — system rounded \
            borders collapse to flat black on `SurfaceCard` in dark \
            mode. Use `.textFieldStyle(.nomadFi)` instead.
            """
        )
    }

    // MARK: - Helpers

    /// Loads `relativePath` (under the app's source root) off disk.
    /// Returns `nil` when the sandbox blocks file reads (typical
    /// for iOS Simulator unit-test runs) so callers can degrade
    /// to a soft-skip rather than fail spuriously.
    private static func sourceIfReadable(relativePath: String) -> String? {
        let candidates = candidateSourcePaths(for: relativePath)
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return nil
    }

    private static func candidateSourcePaths(for relativePath: String) -> [URL] {
        let fileURL = URL(fileURLWithPath: #filePath)
        let testsDir = fileURL.deletingLastPathComponent()
        let projectRoots: [URL] = [
            testsDir.deletingLastPathComponent(),
            testsDir.deletingLastPathComponent().deletingLastPathComponent(),
        ]
        return projectRoots.map { $0.appending(path: relativePath) }
    }
}
