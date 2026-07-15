// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Shared Swift settings applied to every first-party target.
//
// These adopt Swift 6.2's "approachable concurrency" upcoming-feature flags.
// This is a library: default isolation stays `nonisolated` (we deliberately do
// NOT set `defaultIsolation(MainActor.self)`), so callers are never forced onto
// the main actor.
let sharedSwiftSettings: [SwiftSetting] = [
    // `nonisolated async` functions run on the caller's executor.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    // Infer isolated conformances for isolated types.
    .enableUpcomingFeature("InferIsolatedConformances"),
    // Note: `InferSendableFromCaptures` is intentionally omitted. It is already
    // enabled by default in Swift 6 language mode, and enabling it explicitly
    // produces a "feature already enabled" warning.
]

let package = Package(
    name: "ZPLKit",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27)
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
            name: "ZPLKitVerifier",
            targets: ["ZPLKitVerifier"]
        ),
        .library(
            name: "ZPLKitPrinter",
            targets: ["ZPLKitPrinter"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZPLKit",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ZPLKitRenderer",
            dependencies: ["ZPLKit"],
            resources: [
                .copy("Resources/RobotoCondensed-Bold.ttf"),
                .copy("Resources/Roboto-LICENSE.txt")
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitTests",
            dependencies: ["ZPLKit"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitRendererTests",
            dependencies: ["ZPLKitRenderer", "ZPLKitVerifier"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ZPLKitVerifier",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ZPLKitPrinter",
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitPrinterTests",
            dependencies: ["ZPLKitPrinter", "ZPLKit"],
            resources: [
                .copy("Fixtures/RealDevice")
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitVerifierTests",
            dependencies: ["ZPLKitVerifier", "ZPLKit", "ZPLKitRenderer"],
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "RenderFixtures",
            dependencies: ["ZPLKitRenderer"],
            path: "Tools/RenderFixtures",
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "VisualTests",
            dependencies: ["ZPLKitRenderer", "ZPLKitVerifier"],
            path: "Tools/VisualTests",
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "PrinterTests",
            dependencies: ["ZPLKit", "ZPLKitPrinter"],
            path: "Tools/PrinterTests",
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "GraphicPrintTest",
            dependencies: ["ZPLKit", "ZPLKitPrinter"],
            path: "Tools/GraphicPrintTest",
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "DitherTestPrint",
            dependencies: ["ZPLKit", "ZPLKitPrinter"],
            path: "Tools/DitherTestPrint",
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "StatusCheck",
            dependencies: ["ZPLKit", "ZPLKitPrinter"],
            path: "Tools/StatusCheck",
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
