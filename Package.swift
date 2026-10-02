// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TestCommons",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        // Helpers with no testing-framework imports. Safe to link into a shipping
        // binary, so tools such as amoo can depend on it.
        .library(name: "TestCommons", targets: ["TestCommons"]),
        // XCUITest helpers. Link into UI test targets only.
        .library(name: "TestCommonsXCUI", targets: ["TestCommonsXCUI"]),
    ],
    targets: [
        .target(name: "TestCommons"),
        .target(name: "TestCommonsXCUI", dependencies: ["TestCommons"]),
        .testTarget(name: "TestCommonsTests", dependencies: ["TestCommons"]),
        .testTarget(name: "TestCommonsXCUITests", dependencies: ["TestCommonsXCUI"]),
    ],
    swiftLanguageModes: [.v6]
)
