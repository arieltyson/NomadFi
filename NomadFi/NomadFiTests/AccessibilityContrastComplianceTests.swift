import Foundation
import Testing
import UIKit

@testable import NomadFi

@MainActor
struct AccessibilityContrastComplianceTests {

    @Test("AccentColor supports WCAG AA with on-action text in light and dark")
    func accentColorActionPairMeetsWCAGAA() throws {
        let accent = try loadColorSet(named: "AccentColor")
        let minimumAA = 4.5

        #expect(
            accent.light.contrastRatio(against: SRGBColor.white) >= minimumAA,
            "AccentColor light must support white text at 4.5:1 or greater."
        )
        #expect(
            accent.dark.contrastRatio(against: SRGBColor.white) >= minimumAA,
            "AccentColor dark must support white text at 4.5:1 or greater."
        )
    }

    @Test("BrandPrimary remains aligned with AccentColor across appearances")
    func brandPrimaryRemainsAlignedWithAccentColor() throws {
        let accent = try loadColorSet(named: "AccentColor")
        let brandPrimary = try loadColorSet(named: "BrandPrimary")

        #expect(
            brandPrimary.light == accent.light,
            "BrandPrimary light should remain aligned with AccentColor light."
        )
        #expect(
            brandPrimary.dark == accent.dark,
            "BrandPrimary dark should remain aligned with AccentColor dark."
        )
    }

    @Test("BrandSecondary always has an accessible foreground option")
    func brandSecondaryHasAccessibleForegroundOption() throws {
        let brandSecondary = try loadColorSet(named: "BrandSecondary")
        let minimumAA = 4.5

        let lightBest = max(
            brandSecondary.light.contrastRatio(against: SRGBColor.white),
            brandSecondary.light.contrastRatio(against: SRGBColor.black)
        )
        let darkBest = max(
            brandSecondary.dark.contrastRatio(against: SRGBColor.white),
            brandSecondary.dark.contrastRatio(against: SRGBColor.black)
        )

        #expect(
            lightBest >= minimumAA,
            "BrandSecondary light needs either white or black foreground at 4.5:1 or greater."
        )
        #expect(
            darkBest >= minimumAA,
            "BrandSecondary dark needs either white or black foreground at 4.5:1 or greater."
        )
    }
}

private extension AccessibilityContrastComplianceTests {

    func loadColorSet(named name: String) throws -> (light: SRGBColor, dark: SRGBColor) {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
        func resolved(_ style: UIUserInterfaceStyle) throws -> SRGBColor {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            try #require(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            return .init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        }
        return try (resolved(.light), resolved(.dark))
    }
}
