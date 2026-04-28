// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReaditCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ReaditCore", targets: ["ReaditCore"])
    ],
    targets: [
        .target(name: "ReaditCore"),
        .testTarget(name: "ReaditCoreTests", dependencies: ["ReaditCore"])
    ]
)
