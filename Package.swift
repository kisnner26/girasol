// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SunKit",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "SunKit", targets: ["SunKit"]),
        .library(name: "HealthCore", targets: ["HealthCore"]),
        .library(name: "GameCore", targets: ["GameCore"]),
    ],
    targets: [
        .target(name: "SunKit"),
        .target(name: "HealthCore"),
        .target(name: "GameCore"),
        .testTarget(name: "SunKitTests", dependencies: ["SunKit"], resources: [.copy("Fixtures")]),
        .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
    ]
)
