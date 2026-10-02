import CoreGraphics
import Testing

@testable import TestCommons

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
        // 1 and 2 are on one row, 3 wraps to the next, 4 follows 3.
        let frames: [Int: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 10, height: 10),
            2: CGRect(x: 20, y: 0, width: 10, height: 10),
            3: CGRect(x: 0, y: 20, width: 10, height: 10),
            4: CGRect(x: 20, y: 20, width: 10, height: 10),
        ]
        let pair = try #require(ReadingOrder.firstAdjacentPair(in: frames) { $0 + 1 })
        #expect(pair.first == frames[1])
        #expect(pair.second == frames[2])
    }

    @Test("No adjacent pair is found when every neighbour wraps")
    func noAdjacentPair() {
        let frames: [Int: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 10, height: 10),
            2: CGRect(x: 0, y: 20, width: 10, height: 10),
        ]
        #expect(ReadingOrder.firstAdjacentPair(in: frames) { $0 + 1 } == nil)
    }
}
