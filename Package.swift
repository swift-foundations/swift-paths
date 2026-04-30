// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-paths",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "Paths", targets: ["Paths"])
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../../swift-primitives/swift-path-primitives"),
        .package(path: "../swift-kernel")
    ],
    targets: [
        .target(
            name: "Paths",
            dependencies: [
                .product(name: "Path Primitives", package: "swift-path-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives")
            ]
        ),
        .testTarget(
            name: "Paths Tests",
            dependencies: [
                "Paths",
                .product(name: "Kernel Core", package: "swift-kernel")
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
