#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
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

        func testOrderedRowsRecordNoFailure() {
            let third = right.offsetBy(dx: 50, dy: 0)
            XCTAssertReadingOrder([left, right, third], direction: .leftToRight)
            XCTAssertReadingOrder([third, right, left], direction: .rightToLeft, "Persian week")
            XCTAssertReadingOrder([], direction: .leftToRight)
        }

        func testRowViolationsNameTheOffendingIndex() {
            let third = right.offsetBy(dx: 50, dy: 0)
            XCTExpectFailure {
                XCTAssertReadingOrder([left, third, right], direction: .leftToRight, "Week")
            } issueMatcher: { issue in
                issue.compactDescription.contains("Week: frame 2 does not follow frame 1 left to right")
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
