// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZPLKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "ZPLKit",
            targets: ["ZPLKit"]
        ),
        .library(
            name: "ZPLKitRenderer",
            targets: ["ZPLKitRenderer"]
        ),
        .library(
            name: "ZPLVerifier",
            targets: ["ZPLVerifier"]
        ),
        .library(
            name: "ZPLKitPrinter",
            targets: ["ZPLKitPrinter"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/LiveUI/Awesome", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ZPLKit"
        ),
        .target(
            name: "ZPLKitRenderer",
            dependencies: ["ZPLKit"],
            resources: [
                .copy("Resources/RobotoCondensed-Bold.ttf"),
                .copy("Resources/OFL.txt")
            ]
        ),
        .testTarget(
            name: "ZPLKitTests",
            dependencies: ["ZPLKit"]
        ),
        .testTarget(
            name: "ZPLKitRendererTests",
            dependencies: ["ZPLKitRenderer", "ZPLVerifier"]
        ),
        .target(
            name: "ZPLVerifier"
        ),
        .target(
            name: "ZPLKitPrinter"
        ),
        .testTarget(
            name: "ZPLKitPrinterTests",
            dependencies: ["ZPLKitPrinter", "ZPLKit"]
        ),
        .testTarget(
            name: "ZPLVerifierTests",
            dependencies: ["ZPLVerifier", "ZPLKit", "ZPLKitRenderer"]
        ),
        .executableTarget(
            name: "RenderFixtures",
            dependencies: ["ZPLKitRenderer"],
            path: "Tools/RenderFixtures"
        ),
        .executableTarget(
            name: "VisualTests",
            dependencies: ["ZPLKitRenderer", "ZPLVerifier"],
            path: "Tools/VisualTests"
        ),
        .executableTarget(
            name: "GraphicsTest",
            dependencies: ["ZPLKit", "Awesome"],
            path: "Tools/GraphicsTest"
        ),
    ]
)
