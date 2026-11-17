// swift-tools-version: 6.2
import Foundation
import PackageDescription

// SwiftPM names a path dependency after its directory, so the root checkout is
// "TestCommons" locally but "SwiftTestCommons" on CI.
let testCommonsPackage = URL(fileURLWithPath: Context.packageDirectory)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .lastPathComponent

let package = Package(
    name: "ConsumerIntegrationTests",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        .package(path: "../.."),
        .package(path: ProcessInfo.processInfo.environment["USERDEFAULT_MACRO_PATH"] ?? "../../../../UserDefaultMacro"),
    ],
    targets: [
        .testTarget(
            name: "ConsumerIntegrationTests",
            dependencies: [
                .product(name: "TestCommons", package: testCommonsPackage),
                .product(name: "UserDefault", package: "UserDefaultMacro"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
