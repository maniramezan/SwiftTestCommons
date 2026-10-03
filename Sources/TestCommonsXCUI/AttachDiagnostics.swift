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
#endif
