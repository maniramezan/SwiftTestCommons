#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

    /// Applies language and locale arguments before launching an application.
    ///
    /// Replaces previous Apple language/locale pairs without touching app-specific flags.
    /// - Parameters:
    ///   - app: The unlaunched application to configure.
    ///   - language: The language code used in `AppleLanguages`.
    ///   - locale: The locale identifier used in `AppleLocale`.
    @MainActor
    public func configureLocale(of app: XCUIApplication, language: String, locale: String) {
        app.launchArguments = localeLaunchArguments(app.launchArguments, language: language, locale: locale)
    }

    func localeLaunchArguments(_ arguments: [String], language: String, locale: String) -> [String] {
        var arguments = arguments
        for key in ["-AppleLanguages", "-AppleLocale"] {
            while let index = arguments.firstIndex(of: key) {
                arguments.remove(at: index)
                if index < arguments.count {
                    arguments.remove(at: index)
                }
            }
        }
        return arguments + ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
    }
#endif
