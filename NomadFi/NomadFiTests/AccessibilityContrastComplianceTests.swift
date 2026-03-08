import Foundation
import Testing

@testable import NomadFi

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

    var assetCatalogURL: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent() // NomadFiTests
            .deletingLastPathComponent() // project root inside xcodeproj folder
            .appending(path: "NomadFi")
            .appending(path: "Resources")
            .appending(path: "Assets.xcassets")
    }

    func loadColorSet(named name: String) throws -> (light: SRGBColor, dark: SRGBColor) {
        try AssetCatalogColorLoader.loadColorSet(
            named: name,
            fromAssetCatalogAt: assetCatalogURL
        )
    }
}
