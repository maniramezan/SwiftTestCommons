// swift-tools-version: 6.2

import PackageDescription

// Window hosting uses AppKit on macOS and UIKit elsewhere, including Mac Catalyst.
// watchOS has neither, so only offscreen rendering is available there.
let hostingSettings: [SwiftSetting] = [
    .define("HOSTING_APPKIT", .when(platforms: [.macOS])),
    .define("HOSTING_UIKIT", .when(platforms: [.iOS, .tvOS, .visionOS, .macCatalyst])),
]

let package = Package(
    name: "TestCommons",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .visionOS(.v2), .watchOS(.v11)],
    products: [
        // Helpers with no testing-framework imports. Safe to link into a shipping
        // binary, such as a device-automation tool.
        .library(name: "TestCommons", targets: ["TestCommons"]),
        // XCUITest helpers. Link into UI test targets only.
        .library(name: "TestCommonsXCUI", targets: ["TestCommonsXCUI"]),
        // SwiftUI hosting and rendering helpers. Link into hosted-view test targets.
        .library(name: "TestCommonsUI", targets: ["TestCommonsUI"]),
    ],
    targets: [
        .target(name: "TestCommons"),
        .target(name: "TestCommonsUI", swiftSettings: hostingSettings),
        .testTarget(name: "TestCommonsUITests", dependencies: ["TestCommonsUI"], swiftSettings: hostingSettings),
        .target(name: "TestCommonsXCUI", dependencies: ["TestCommons"]),
        .testTarget(name: "TestCommonsTests", dependencies: ["TestCommons"]),
        .testTarget(name: "TestCommonsXCUITests", dependencies: ["TestCommonsXCUI"]),
    ],
    swiftLanguageModes: [.v6]
)
