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
    dependencies: [
        // No tagged release yet; pin to a known-good commit on main.
        .package(
            url: "https://github.com/neolee/swift-readability.git",
            revision: "2ff3dc57a4526fea494e0a82c1defcb06ce60810"
        ),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.4")
    ],
    targets: [
        .target(
            name: "ReaditCore",
            dependencies: [
                .product(name: "Readability", package: "swift-readability"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
        .testTarget(name: "ReaditCoreTests", dependencies: ["ReaditCore"])
    ]
)
