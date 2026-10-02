#if canImport(XCTest)
    import CoreGraphics
    import TestCommons
    import XCTest

    /// Asserts that two frames follow `direction`, failing with `label` for context.
    ///
    /// Frames must be finite and nonempty and use the same screen-coordinate space.
    /// Vertical centers must differ by less than `rowTolerance`, and horizontal
    /// centers must advance strictly in `direction`. Overlap is allowed.
    /// Invalid geometry, an invalid tolerance, or a direction mismatch records
    /// one XCTest failure containing both frames at the supplied source location.
    ///
    /// - Parameters:
    ///   - first: The frame expected to occur earlier in reading order.
    ///   - second: The frame expected to occur later in reading order.
    ///   - direction: The expected horizontal reading direction.
    ///   - label: Optional context prefixed to the failure message.
    ///   - rowTolerance: The finite, positive, exclusive vertical-center tolerance in points.
    ///   - file: The calling test's source file. Leave the default to preserve its location.
    ///   - line: The calling test's source line. Leave the default to preserve its location.
    public func XCTAssertReadingOrder(
        first: CGRect, second: CGRect, direction: ReadingDirection, _ label: String = "",
        rowTolerance: CGFloat = ReadingOrder.defaultRowTolerance,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let prefix = label.isEmpty ? "" : "\(label): "
        guard ReadingOrder.sharesRow(first, second, tolerance: rowTolerance) else {
            XCTFail(
                "\(prefix)expected valid frames on the same row (tolerance: \(rowTolerance)); first: \(first), second: \(second)",
                file: file, line: line)
            return
        }
        XCTAssertTrue(
            ReadingOrder.follows(second, first, in: direction, rowTolerance: rowTolerance),
            "\(prefix)expected content to run \(direction == .rightToLeft ? "right to left" : "left to right"); first: \(first), second: \(second)",
            file: file, line: line)
    }
#endif
