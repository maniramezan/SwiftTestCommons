// swift-tools-version: 6.2
import Foundation
import PackageDescription

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
                .product(name: "TestCommons", package: "TestCommons"),
                .product(name: "UserDefault", package: "UserDefaultMacro"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
