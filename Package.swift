// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snow",
    platforms: [.macOS(.v12)],
    products: [.library(name: "SnowCore", targets: ["SnowCore"])],
    targets: [
        .target(name: "SnowCore"),
        .testTarget(name: "SnowCoreTests", dependencies: ["SnowCore"])
    ]
)
