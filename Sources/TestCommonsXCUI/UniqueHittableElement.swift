#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

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
#endif
