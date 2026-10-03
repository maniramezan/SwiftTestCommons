#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

    /// Attaches an application's screenshot and accessibility hierarchy to a test.
    /// - Parameters:
    ///   - app: The application to capture.
    ///   - testCase: The test receiving the attachments.
    ///   - name: The prefix used for attachment names.
    ///   - lifetime: Whether attachments persist after a successful test.
    @MainActor
    public func attachDiagnostics(
        of app: XCUIApplication, to testCase: XCTestCase, named name: String = "Failure",
        lifetime: XCTAttachment.Lifetime = .keepAlways
    ) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name) screenshot"
        screenshot.lifetime = lifetime
        testCase.add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) UI hierarchy"
        hierarchy.lifetime = lifetime
        testCase.add(hierarchy)
    }

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

    /// Returns the sole currently hittable match, reporting ambiguous queries.
    ///
    /// This performs no waiting. Zero matches returns nil; multiple matches record a failure.
    /// - Parameters:
    ///   - query: The caller's explicitly scoped element query.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: The unique hittable element, or nil when absent or ambiguous.
    @MainActor
    public func uniqueHittableElement(
        in query: XCUIElementQuery, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement? {
        let matches = query.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        guard matches.count <= 1 else {
            XCTFail(
                "Expected one hittable element, found \(matches.count).\n\(query.debugDescription)", file: file,
                line: line)
            return nil
        }
        return matches.first
    }

    /// Replaces text in a plain editable field and verifies its accessibility value.
    ///
    /// Supports fields whose string value exposes their actual contents, not secure
    /// fields or placeholder-only values. The caller supplies the trailing caret location.
    /// - Parameters:
    ///   - element: A hittable, plain text field with an actual string value.
    ///   - text: The replacement text; empty clears the field.
    ///   - caretOffset: A normalized coordinate placing the caret after the existing text.
    ///   - timeout: The combined readiness and verification budget in seconds.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the final accessibility value matches the replacement.
    @MainActor
    @discardableResult
    public func replaceText(
        in element: XCUIElement, with text: String,
        caretOffset: CGVector = CGVector(dx: 0.95, dy: 0.5), timeout: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        let start = ContinuousClock.now
        guard waitForHittability(element, timeout: timeout, file: file, line: line) else {
            return false
        }
        guard let current = element.value as? String else {
            XCTFail(
                "Editable field did not expose a string value.\n\(element.debugDescription)", file: file, line: line)
            return false
        }
        element.coordinate(withNormalizedOffset: caretOffset).tap()
        if !current.isEmpty {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !text.isEmpty {
            element.typeText(text)
        }
        let remaining = remainingTimeout(timeout, elapsed: start.duration(to: .now))
        return waitForValue(text, on: element, timeout: remaining, file: file, line: line)
    }

    func remainingTimeout(_ timeout: TimeInterval, elapsed: Duration) -> TimeInterval {
        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return max(0, timeout - seconds)
    }
#endif
