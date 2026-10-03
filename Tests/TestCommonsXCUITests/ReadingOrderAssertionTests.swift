#if os(macOS) || os(iOS)
    import CoreGraphics
    import TestCommons
    import XCTest

    @testable import TestCommonsXCUI

    // XCTest rather than Swift Testing: Swift Testing downgrades XCTest assertion
    // failures to warnings, so only XCTExpectFailure can observe this assertion failing.
    final class ReadingOrderAssertionTests: XCTestCase {
        private let left = CGRect(x: 0, y: 0, width: 40, height: 40)
        private let right = CGRect(x: 50, y: 0, width: 40, height: 40)

        func testMatchingOrderRecordsNoFailure() {
            XCTAssertReadingOrder(first: left, second: right, direction: .leftToRight)
            XCTAssertReadingOrder(first: right, second: left, direction: .rightToLeft, "Persian")
        }

        func testReversedOrderReportsDirectionAndLabel() {
            XCTExpectFailure {
                XCTAssertReadingOrder(first: left, second: right, direction: .rightToLeft, "Persian")
            } issueMatcher: { issue in
                issue.compactDescription.contains("Persian: expected content to run right to left")
            }
        }

        func testDifferentRowsReportTheTolerance() {
            XCTExpectFailure {
                XCTAssertReadingOrder(
                    first: left, second: right.offsetBy(dx: 0, dy: 5), direction: .leftToRight, rowTolerance: 2)
            } issueMatcher: { issue in
                issue.compactDescription.contains("same row (tolerance: 2.0)")
            }
        }

        func testInvalidFramesFail() {
            XCTExpectFailure {
                XCTAssertReadingOrder(first: .zero, second: right, direction: .leftToRight)
            } issueMatcher: { issue in
                issue.compactDescription.contains("expected valid frames on the same row")
            }
        }
    }
#endif
