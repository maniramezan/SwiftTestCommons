#if canImport(XCTest)
    import XCTest

    /// Waits for an element to exist, reporting failures at the caller.
    ///
    /// Runs on the main actor. Failure records an XCTest assertion with the
    /// element's debug description, even when the returned flag is ignored.
    /// Existence does not imply that the element is enabled or hittable.
    ///
    /// - Parameters:
    ///   - element: The element expected to appear in the accessibility hierarchy.
    ///   - timeout: The maximum wait duration, in seconds. Pass a nonnegative value.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists before the timeout; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForExistence(
        _ element: XCUIElement, timeout: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        let succeeded = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            succeeded, "Element did not exist before the timeout.\n\(element.debugDescription)",
            file: file, line: line)
        return succeeded
    }

    /// Waits for existence and readiness together, using one timeout budget.
    ///
    /// Runs on the main actor and requires both `exists` and `isEnabled` to be
    /// true. Enabled controls may still be obscured or outside the viewport.
    /// Failure records an XCTest assertion with the element's debug description.
    ///
    /// - Parameters:
    ///   - element: The control expected to appear and become enabled.
    ///   - timeout: The maximum combined wait duration, in seconds. Pass a nonnegative value.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when existence and enabled state match; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForEnabled(
        _ element: XCUIElement, timeout: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .enabled, timeout: timeout,
            file: file, line: line)
    }

    /// Waits for an existing element to expose exactly the expected string value.
    ///
    /// Runs on the main actor. Matching is case-sensitive and compares the
    /// accessibility value, not the label. Existence and value share one timeout.
    /// Failure records an XCTest assertion with the element's debug description.
    ///
    /// - Parameters:
    ///   - value: The exact string expected in the element's accessibility value.
    ///   - element: The element whose value is observed.
    ///   - timeout: The maximum combined wait duration, in seconds. Pass a nonnegative value.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists with the expected value; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForValue(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .value(value), timeout: timeout,
            file: file, line: line)
    }

    /// Waits for an existing element's string value to contain the expected text.
    ///
    /// Runs on the main actor. Matching is a case-sensitive substring comparison
    /// of the accessibility value, not the label. Existence and value share one timeout.
    /// Failure records an XCTest assertion with the element's debug description.
    ///
    /// - Parameters:
    ///   - value: The literal substring expected in the accessibility value.
    ///   - element: The element whose value is observed.
    ///   - timeout: The maximum combined wait duration, in seconds. Pass a nonnegative value.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists with a matching value; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForValueContaining(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .valueContaining(value), timeout: timeout,
            file: file, line: line)
    }

    @MainActor
    private func waitForElement(
        _ element: XCUIElement, condition: ElementCondition, timeout: TimeInterval,
        file: StaticString, line: UInt
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: condition.predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let succeeded = result == .completed
        XCTAssertTrue(
            succeeded,
            "Element did not \(condition.description) before the timeout (\(result)).\n\(element.debugDescription)",
            file: file, line: line)
        return succeeded
    }

    enum ElementCondition {
        case enabled
        case value(String)
        case valueContaining(String)

        var predicate: NSPredicate {
            switch self {
            case .enabled:
                NSPredicate(format: "exists == true AND isEnabled == true")
            case .value(let value):
                NSPredicate(format: "exists == true AND value == %@", value)
            case .valueContaining(let value):
                NSPredicate(format: "exists == true AND value CONTAINS %@", value)
            }
        }

        var description: String {
            switch self {
            case .enabled: "exist and become enabled"
            case .value(let value): "exist with value equal to '\(value)'"
            case .valueContaining(let value): "exist with value containing '\(value)'"
            }
        }
    }
#endif
