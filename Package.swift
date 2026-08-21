// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-paths",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Paths", targets: ["Paths"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-primitives/swift-binary-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-binary-serializer-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-path-primitives.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Paths",
            dependencies: [
                .product(name: "Path Primitives", package: "swift-path-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(
                    name: "Binary Serializable Primitives",
                    package: "swift-binary-serializer-primitives"
                ),
            ]
        ),
        .testTarget(
            name: "Paths Tests",
            dependencies: [
                "Paths",
                .product(name: "Kernel Core", package: "swift-kernel"),
            ]
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
