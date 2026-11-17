#if canImport(XCTest) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
    import TestCommons
    import XCTest

    /// Forces the application's layout direction before launch, independent of its language.
    ///
    /// Use right-to-left to check mirrored layouts without translating the app. Replaces earlier
    /// direction arguments without touching app-specific flags.
    /// - Parameters:
    ///   - app: The unlaunched application to configure.
    ///   - direction: The layout direction to force.
    @MainActor
    public func configureLayoutDirection(of app: XCUIApplication, _ direction: ReadingDirection) {
        app.launchArguments = layoutDirectionLaunchArguments(app.launchArguments, direction)
    }

    func layoutDirectionLaunchArguments(_ arguments: [String], _ direction: ReadingDirection) -> [String] {
        let rightToLeft = direction == .rightToLeft ? "YES" : "NO"
        return replacingLaunchArguments(
            arguments,
            with: [("-AppleTextDirection", rightToLeft), ("-NSForceRightToLeftWritingDirection", rightToLeft)])
    }
#endif
