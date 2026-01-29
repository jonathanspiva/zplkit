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
            dependencies: ["ZPLKitRenderer"]
        ),
        .executableTarget(
            name: "RenderFixtures",
            dependencies: ["ZPLKitRenderer"],
            path: "Tools/RenderFixtures"
        ),
    ]
)
