#if canImport(XCTest) && (os(macOS) || os(iOS) || os(visionOS))
    import XCTest

    /// Replaces text in a plain editable field and verifies its accessibility value.
    ///
    /// Supports fields whose string value exposes their actual contents, not secure fields.
    /// A value equal to the field's placeholder is treated as empty, both before typing and
    /// when verifying that an empty replacement cleared the field. Deletes one key per
    /// Unicode scalar, so text with combining marks or joiners is fully cleared; surplus
    /// deletes in an empty field have no effect. The caller supplies the trailing caret location.
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
        let placeholder = element.placeholderValue
        let deletions = deletionCount(for: current, placeholder: placeholder)
        if deletions > 0 {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deletions))
        }
        if !text.isEmpty {
            element.typeText(text)
        }
        let remaining = remainingTimeout(timeout, elapsed: start.duration(to: .now))
        let expected: ElementCondition = text.isEmpty ? .emptyValue(placeholder: placeholder) : .value(text)
        return waitForElement(element, condition: expected, timeout: remaining, name: name, file: file, line: line)
    }

    /// The delete keystrokes needed to clear `value`, or zero when it is only the placeholder.
    ///
    /// One backspace removes at least one Unicode scalar, so the scalar count is enough even
    /// when a backspace removes a whole grapheme cluster.
    func deletionCount(for value: String, placeholder: String?) -> Int {
        if let placeholder, !placeholder.isEmpty, value == placeholder {
            return 0
        }
        return value.unicodeScalars.count
    }

    func remainingTimeout(_ timeout: TimeInterval, elapsed: Duration) -> TimeInterval {
        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return max(0, timeout - seconds)
    }
#endif
