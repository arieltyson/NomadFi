// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NomadFiPlanning",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "FiBotEngine", targets: ["FiBotEngine"]), .executable(name: "fibot-evaluate", targets: ["FiBotCLI"])],
    targets: [
        .target(name: "FiBotEngine", path: "NomadFi/NomadFi/Core/FiBot/Engine"),
        .executableTarget(name: "FiBotCLI", dependencies: ["FiBotEngine"], path: "services/fibot-engine/Sources"),
        .testTarget(name: "FiBotEngineTests", dependencies: ["FiBotEngine"], path: "services/fibot-engine/Tests"),
    ]
)
