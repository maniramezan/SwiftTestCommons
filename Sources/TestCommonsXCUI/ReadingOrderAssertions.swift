#if canImport(XCTest)
    import CoreGraphics
    import TestCommons
    import XCTest

    /// Asserts that two frames follow `direction`, failing with `label` for context.
    public func XCTAssertReadingOrder(
        first: CGRect, second: CGRect, direction: ReadingDirection, _ label: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let prefix = label.isEmpty ? "" : "\(label): "
        guard ReadingOrder.sharesRow(first, second) else {
            XCTFail("\(prefix)frames are not on the same row", file: file, line: line)
            return
        }
        XCTAssertTrue(
            ReadingOrder.follows(second, first, in: direction),
            "\(prefix)expected content to run \(direction == .rightToLeft ? "right to left" : "left to right")",
            file: file, line: line)
    }
#endif
