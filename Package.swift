// swift-tools-version: 6.0
//
// RoadOS iOS SDK. Swift / SwiftUI / UIKit API over RoadOS Graphics Core
// (C++20 + Skia), the single rendering engine shared with the Android SDK.
//
// Binaries/RoadOSCore.xcframework and Sources/RoadOSGraphics/Resources/rvhl are
// produced by scripts/build_xcframework.sh from the pinned core submodule.
// Run that script once after cloning (see README).
import PackageDescription

let package = Package(
    name: "RoadOSGraphics",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),  // for `swift test` on Apple-silicon Macs
    ],
    products: [
        .library(name: "RoadOSGraphics", targets: ["RoadOSGraphics"]),
    ],
    targets: [
        .binaryTarget(
            name: "RoadOSCore",
            path: "Binaries/RoadOSCore.xcframework"
        ),
        .target(
            name: "RoadOSBridge",
            dependencies: ["RoadOSCore"],
            path: "Sources/RoadOSBridge",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreServices", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "RoadOSGraphics",
            dependencies: ["RoadOSBridge"],
            path: "Sources/RoadOSGraphics",
            resources: [.copy("Resources/rvhl")]
        ),
        .testTarget(
            name: "RoadOSGraphicsTests",
            dependencies: ["RoadOSGraphics"],
            path: "Tests/RoadOSGraphicsTests"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
