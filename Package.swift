// swift-tools-version: 6.3
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
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
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
                .copy("Resources/OFL.txt")
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
            dependencies: ["ZPLKitRenderer", "ZPLVerifier"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ZPLVerifier",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ZPLKitPrinter",
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitPrinterTests",
            dependencies: ["ZPLKitPrinter", "ZPLKit"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLVerifierTests",
            dependencies: ["ZPLVerifier", "ZPLKit", "ZPLKitRenderer"],
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
            dependencies: ["ZPLKitRenderer", "ZPLVerifier"],
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
