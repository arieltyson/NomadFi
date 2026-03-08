import Foundation

/// Standard sRGB color representation used for WCAG contrast checks.
struct SRGBColor: Sendable, Equatable {

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let white = SRGBColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = SRGBColor(red: 0, green: 0, blue: 0, alpha: 1)

    /// WCAG 2.x relative luminance.
    var relativeLuminance: Double {
        (0.2126 * red.linearized) + (0.7152 * green.linearized) + (0.0722 * blue.linearized)
    }

    /// WCAG contrast ratio between two colors.
    func contrastRatio(against other: SRGBColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

enum AssetCatalogColorLoader {

    enum LoaderError: Error, CustomStringConvertible {
        case missingColorVariant(String)
        case malformedComponent(String)

        var description: String {
            switch self {
            case let .missingColorVariant(name):
                return "Missing light or dark color variant in \(name).colorset"
            case let .malformedComponent(value):
                return "Invalid numeric component value: \(value)"
            }
        }
    }

    /// Loads light and dark variants from an .xcassets colorset.
    static func loadColorSet(
        named colorSetName: String,
        fromAssetCatalogAt catalogURL: URL
    ) throws -> (light: SRGBColor, dark: SRGBColor) {
        let colorSetURL = catalogURL
            .appending(path: "\(colorSetName).colorset")
            .appending(path: "Contents.json")

        let data = try Data(contentsOf: colorSetURL)
        let contents = try JSONDecoder().decode(ColorSetContents.self, from: data)

        guard let light = contents.colors.first(where: { !$0.isDarkVariant }),
              let dark = contents.colors.first(where: \.isDarkVariant) else {
            throw LoaderError.missingColorVariant(colorSetName)
        }

        return (try light.components.toSRGB(), try dark.components.toSRGB())
    }
}

// MARK: - Internal Decoding Models

private struct ColorSetContents: Decodable {
    let colors: [ColorSetEntry]
}

private struct ColorSetEntry: Decodable {
    let appearances: [ColorAppearance]?
    let color: ColorPayload

    var isDarkVariant: Bool {
        guard let appearances else { return false }
        return appearances.contains { appearance in
            appearance.appearance == "luminosity" && appearance.value == "dark"
        }
    }

    var components: ColorComponents {
        color.components
    }
}

private struct ColorAppearance: Decodable {
    let appearance: String
    let value: String
}

private struct ColorPayload: Decodable {
    let components: ColorComponents
}

private struct ColorComponents: Decodable {
    let red: String
    let green: String
    let blue: String
    let alpha: String

    func toSRGB() throws -> SRGBColor {
        guard let redValue = Double(red) else {
            throw AssetCatalogColorLoader.LoaderError.malformedComponent(red)
        }
        guard let greenValue = Double(green) else {
            throw AssetCatalogColorLoader.LoaderError.malformedComponent(green)
        }
        guard let blueValue = Double(blue) else {
            throw AssetCatalogColorLoader.LoaderError.malformedComponent(blue)
        }
        guard let alphaValue = Double(alpha) else {
            throw AssetCatalogColorLoader.LoaderError.malformedComponent(alpha)
        }

        return SRGBColor(
            red: redValue,
            green: greenValue,
            blue: blueValue,
            alpha: alphaValue
        )
    }
}

private extension Double {
    var linearized: Double {
        if self <= 0.04045 {
            return self / 12.92
        }

        return pow((self + 0.055) / 1.055, 2.4)
    }
}
