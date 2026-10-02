#if canImport(CoreGraphics)
    import CoreGraphics
#else
    import Foundation
#endif
import Testing

import TestCommons

@Suite("ReadingOrder")
struct ReadingOrderTests {
    private let left = CGRect(x: 0, y: 100, width: 40, height: 40)
    private let right = CGRect(x: 50, y: 100, width: 40, height: 40)
    private let below = CGRect(x: 50, y: 160, width: 40, height: 40)

    @Test("A frame to the right follows in left-to-right, not in right-to-left")
    func leftToRight() {
        #expect(ReadingOrder.follows(right, left, in: .leftToRight))
        #expect(!ReadingOrder.follows(right, left, in: .rightToLeft))
    }

    @Test("A frame to the left follows in right-to-left, not in left-to-right")
    func rightToLeft() {
        #expect(ReadingOrder.follows(left, right, in: .rightToLeft))
        #expect(!ReadingOrder.follows(left, right, in: .leftToRight))
    }

    @Test("Frames on different rows never follow each other")
    func differentRows() {
        #expect(!ReadingOrder.follows(below, left, in: .leftToRight))
        #expect(!ReadingOrder.follows(below, left, in: .rightToLeft))
    }

    @Test("Row tolerance is honoured")
    func rowTolerance() {
        let nudged = right.offsetBy(dx: 0, dy: 3)
        #expect(!ReadingOrder.sharesRow(left, nudged))
        #expect(ReadingOrder.sharesRow(left, nudged, tolerance: 5))
    }

    @Test("The first adjacent pair skips a row break")
    func adjacentPair() throws {
        // 1 ends a row; 2 and 3 are the first adjacent pair on the next row.
        let frames: [Int: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 10, height: 10),
            2: CGRect(x: 20, y: 20, width: 10, height: 10),
            3: CGRect(x: 0, y: 20, width: 10, height: 10),
            4: CGRect(x: 20, y: 20, width: 10, height: 10),
        ]
        let pair = try #require(ReadingOrder.firstAdjacentPair(in: frames) { $0 + 1 })
        #expect(pair.first == frames[2])
        #expect(pair.second == frames[3])
    }

    @Test("No adjacent pair is found when every neighbour wraps")
    func noAdjacentPair() {
        let frames: [Int: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 10, height: 10),
            2: CGRect(x: 0, y: 20, width: 10, height: 10),
        ]
        #expect(ReadingOrder.firstAdjacentPair(in: frames) { $0 + 1 } == nil)
    }

    @Test("Rows compare centers rather than top edges")
    func centersDefineRows() {
        let taller = CGRect(x: 50, y: 90, width: 20, height: 60)
        #expect(ReadingOrder.sharesRow(left, taller))
        #expect(ReadingOrder.follows(taller, left, in: .leftToRight))
        let sameTop = CGRect(x: 50, y: 100, width: 20, height: 60)
        #expect(ReadingOrder.sharesRow(left, sameTop) == false)
    }

    @Test("Tolerance boundary is exclusive")
    func toleranceBoundary() {
        let shifted = right.offsetBy(dx: 0, dy: 1)
        #expect(ReadingOrder.sharesRow(left, shifted) == false)
        #expect(ReadingOrder.sharesRow(left, shifted, tolerance: 1.01))
        #expect(ReadingOrder.follows(shifted, left, in: .leftToRight, rowTolerance: 1.01))
    }

    @Test(arguments: [CGFloat.zero, -1, .infinity, .nan])
    func invalidToleranceDoesNotMatch(tolerance: CGFloat) {
        #expect(ReadingOrder.sharesRow(left, right, tolerance: tolerance) == false)
        #expect(ReadingOrder.follows(right, left, in: .leftToRight, rowTolerance: tolerance) == false)
    }

    @Test(arguments: [
        CGRect.zero, .null, .infinite,
        CGRect(x: CGFloat.nan, y: 100, width: 40, height: 40),
        CGRect(x: 50, y: 100, width: CGFloat.infinity, height: 40),
        CGRect(x: 50, y: 100, width: 40, height: 0),
    ])
    func invalidFramesDoNotMatch(frame: CGRect) {
        #expect(ReadingOrder.sharesRow(left, frame) == false)
        #expect(ReadingOrder.sharesRow(frame, left) == false)
        #expect(ReadingOrder.follows(frame, left, in: .leftToRight) == false)
        #expect(ReadingOrder.follows(left, frame, in: .rightToLeft) == false)
    }

    @Test(arguments: [ReadingDirection.leftToRight, .rightToLeft])
    func equalHorizontalCentersDoNotFollow(direction: ReadingDirection) {
        let narrower = CGRect(x: 10, y: 100, width: 20, height: 40)
        #expect(ReadingOrder.follows(narrower, left, in: direction) == false)
        #expect(ReadingOrder.follows(left, left, in: direction) == false)
    }

    @Test
    func missingSuccessorsAreNotReplacedByTheNextSortedKey() {
        let frames = [1: left, 3: right]
        #expect(ReadingOrder.firstAdjacentPair(in: frames) { $0 + 1 } == nil)
        #expect(ReadingOrder.firstAdjacentPair(in: [Int: CGRect]()) { $0 + 1 } == nil)
        #expect(ReadingOrder.firstAdjacentPair(in: [1: left]) { $0 + 1 } == nil)
    }

    @Test
    func adjacentPairSkipsInvalidFrames() throws {
        let pair = try #require(
            ReadingOrder.firstAdjacentPair(in: [1: .zero, 2: left, 3: right]) { $0 + 1 })
        #expect(pair.first == left)
        #expect(pair.second == right)
    }

    @Test
    func customSuccessorAndToleranceWorkWithNonIntegerKeys() throws {
        let shifted = right.offsetBy(dx: 0, dy: 2)
        let frames = ["a": left, "b": shifted]
        #expect(ReadingOrder.firstAdjacentPair(in: frames, successor: { _ in "b" }) == nil)
        let pair = try #require(
            ReadingOrder.firstAdjacentPair(
                in: frames, successor: { $0 == "a" ? "b" : "c" }, rowTolerance: 3))
        #expect(pair.first == left)
        #expect(pair.second == shifted)
    }
}
