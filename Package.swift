// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-paths",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "Paths", targets: ["Paths"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-kernel-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "Paths",
            dependencies: [
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
            ]
        ),
        .testTarget(
            name: "Paths Tests",
            dependencies: ["Paths"]
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
