// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SunKit",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "SunKit", targets: ["SunKit"]),
        .library(name: "HealthCore", targets: ["HealthCore"]),
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "Localization", targets: ["Localization"]),
    ],
    targets: [
        .target(name: "Localization"),
        .target(name: "SunKit", dependencies: ["Localization"]),
        .target(name: "HealthCore", dependencies: ["Localization"]),
        .target(name: "GameCore"),
        .testTarget(name: "SunKitTests", dependencies: ["SunKit"], resources: [.copy("Fixtures")]),
        .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore", "Localization"]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
    ]
)
