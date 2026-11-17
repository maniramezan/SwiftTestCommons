#if canImport(XCTest) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
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
    ///   - name: Optional logical control name included in failure diagnostics.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists before the timeout; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForExistence(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        let succeeded = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            succeeded, "\(name) did not exist before the timeout.\n\(element.debugDescription)",
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
    ///   - name: Optional logical control name included in failure diagnostics.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when existence and enabled state match; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForEnabled(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .enabled, timeout: timeout,
            name: name, file: file, line: line)
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
    ///   - name: Optional logical control name included in failure diagnostics.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists with the expected value; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForValue(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .value(value), timeout: timeout,
            name: name, file: file, line: line)
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
    ///   - name: Optional logical control name included in failure diagnostics.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    /// - Returns: `true` when the element exists with a matching value; otherwise `false`.
    @MainActor
    @discardableResult
    public func waitForValueContaining(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .valueContaining(value), timeout: timeout,
            name: name, file: file, line: line)
    }

    /// Waits for an element to exist and become hittable, reporting failure at the caller.
    /// - Parameters:
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForHittability(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(element, condition: .hittable, timeout: timeout, name: name, file: file, line: line)
    }

    /// Waits for an element to disappear, reporting failure at the caller.
    ///
    /// Uses XCTest's native non-existence wait.
    /// - Parameters:
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForAbsence(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        let succeeded = element.waitForNonExistence(timeout: timeout)
        XCTAssertTrue(
            succeeded,
            "\(name) did not \(ElementCondition.absent.description) before the timeout.\n\(element.debugDescription)",
            file: file, line: line)
        return succeeded
    }

    /// Waits for an element to exist and become selected, reporting failure at the caller.
    ///
    /// Useful for tabs, segmented controls, and list rows whose selection follows a tap.
    /// - Parameters:
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForSelection(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(element, condition: .selected, timeout: timeout, name: name, file: file, line: line)
    }

    /// Waits for an element to exist and gain focus, reporting failure at the caller.
    ///
    /// Focus is reported for keyboard and remote focus, such as on macOS and tvOS.
    /// - Parameters:
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForFocus(
        _ element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(element, condition: .focused, timeout: timeout, name: name, file: file, line: line)
    }

    /// Waits for a query to match exactly `count` elements, reporting failure at the caller.
    ///
    /// Useful after inserting or deleting rows. The failure message includes the query's
    /// debug description.
    /// - Parameters:
    ///   - count: The nonnegative number of expected matches.
    ///   - query: The caller's explicitly scoped element query.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical query name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the count matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForCount(
        _ count: Int, of query: XCUIElementQuery, timeout: TimeInterval,
        named name: String = "Query", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        precondition(count >= 0)
        let predicate = ElementCondition.queryCount(count)
        if predicate.evaluate(with: query) { return true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: query)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let succeeded = result == .completed
        XCTAssertTrue(
            succeeded,
            "\(name) did not match \(count) elements before the timeout (\(result)); found \(query.count).\n\(query.debugDescription)",
            file: file, line: line)
        return succeeded
    }

    /// Waits for an element to expose exactly the expected label, reporting failure at the caller.
    /// - Parameters:
    ///   - value: The case-sensitive label text to match.
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForLabel(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(element, condition: .label(value), timeout: timeout, name: name, file: file, line: line)
    }

    /// Waits for an element to expose a label containing the expected text, reporting failure at the caller.
    /// - Parameters:
    ///   - value: The case-sensitive label text to match.
    ///   - element: The element to observe.
    ///   - timeout: The nonnegative total wait budget in seconds.
    ///   - name: Optional logical control name for diagnostics.
    ///   - file: The calling test's file.
    ///   - line: The calling test's line.
    /// - Returns: Whether the condition matched before the timeout.
    @MainActor
    @discardableResult
    public func waitForLabelContaining(
        _ value: String, on element: XCUIElement, timeout: TimeInterval,
        named name: String = "Element", file: StaticString = #filePath, line: UInt = #line
    ) -> Bool {
        waitForElement(
            element, condition: .labelContaining(value), timeout: timeout, name: name, file: file, line: line)
    }

    @MainActor
    func waitForElement(
        _ element: XCUIElement, condition: ElementCondition, timeout: TimeInterval,
        name: String, file: StaticString, line: UInt
    ) -> Bool {
        let predicate = condition.predicate
        if predicate.evaluate(with: element) { return true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let succeeded = result == .completed
        XCTAssertTrue(
            succeeded,
            "\(name) did not \(condition.description) before the timeout (\(result)).\n\(element.debugDescription)",
            file: file, line: line)
        return succeeded
    }
#endif
