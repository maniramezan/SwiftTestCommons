#if canImport(XCTest) && (os(iOS) || os(tvOS) || os(visionOS))
    import XCTest

    /// Sets the application's Dynamic Type size before launch.
    ///
    /// Replaces an earlier size argument without touching app-specific flags.
    /// - Parameters:
    ///   - app: The unlaunched application to configure.
    ///   - category: A `UIContentSizeCategory` raw value, such as
    ///     `UICTContentSizeCategoryAccessibilityXXXL` or `UIContentSizeCategory.extraLarge.rawValue`.
    @MainActor
    public func configureContentSizeCategory(of app: XCUIApplication, _ category: String) {
        app.launchArguments = contentSizeLaunchArguments(app.launchArguments, category)
    }

    func contentSizeLaunchArguments(_ arguments: [String], _ category: String) -> [String] {
        replacingLaunchArguments(arguments, with: [("-UIPreferredContentSizeCategoryName", category)])
    }
#endif
