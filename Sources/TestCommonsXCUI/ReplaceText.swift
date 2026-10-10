#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

    /// Replaces text in a plain editable field and verifies its accessibility value.
    ///
    /// Supports fields whose string value exposes their actual contents, not secure
    /// fields or placeholder-only values. The caller supplies the trailing caret location.
    /// - Parameters:
    ///   - element: A hittable, plain text field with an actual string value.
    ///   - text: The replacement text; empty clears the field.
    ///   - caretOffset: A normalized coordinate placing the caret after the existing text.
    ///   - timeout: The combined readiness and verification budget in seconds.
    ///   - name: Optional logical field name included in failure diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the final accessibility value matches the replacement.
    @MainActor
    @discardableResult
    public func replaceText(
        in element: XCUIElement, with text: String,
        caretOffset: CGVector = CGVector(dx: 0.95, dy: 0.5), timeout: TimeInterval,
        named name: String = "Editable field", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        let start = ContinuousClock.now
        guard waitForHittability(element, timeout: timeout, named: name, file: file, line: line) else {
            return false
        }
        guard let current = element.value as? String else {
            XCTFail(
                "\(name) did not expose a string value.\n\(element.debugDescription)", file: file, line: line)
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
        return waitForValue(text, on: element, timeout: remaining, named: name, file: file, line: line)
    }

    func remainingTimeout(_ timeout: TimeInterval, elapsed: Duration) -> TimeInterval {
        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return max(0, timeout - seconds)
    }
#endif
