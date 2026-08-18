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
    // Floor is the newest GA release, not the beta. ZPLKit needs nothing above
    // it: the Swift-native Vision API shipped in iOS 18 / macOS 15, and
    // `NetworkConnection` (used by `query()`) is macOS 26. Targeting the beta
    // would make the package uninstallable for anyone on a shipping OS and
    // unbuildable by Swift Package Index, for no capability gain.
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
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZPLKit",
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ZPLKitTests",
            dependencies: ["ZPLKit"],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)

// ZPLKit (ZPL generation) is the only portable target: its sole platform
// dependency, the CoreGraphics-backed `Graphic` element, is already behind
// `#if canImport`. ZPLKitRenderer needs CoreGraphics, ZPLKitVerifier needs
// Vision, and ZPLKitPrinter needs Network, none of which exist off Apple
// platforms.
//
// SwiftPM evaluates this manifest on the *host*, so this decides what a given
// build sees. On Linux the package is just ZPLKit plus its tests, so
// `swift build` and `swift test` both work there instead of failing on the
// first Apple-only import. On Apple platforms the package is unchanged.
//
// SwiftPM has no declarative way to make a *target* conditional (SE-0273's
// `.when(platforms:)` covers dependencies and build settings, not target
// inclusion), so a manifest conditional is the supported approach. SwiftPM's
// own Package.swift and swift-nio's do the same thing.
#if canImport(Darwin)
package.products.append(contentsOf: [
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
])

package.targets.append(contentsOf: [
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
        name: "BarcodePrintTest",
        dependencies: ["ZPLKit", "ZPLKitPrinter"],
        path: "Tools/BarcodePrintTest",
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
])
#endif
