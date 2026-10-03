import Foundation
import Testing
import TestCommons

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

struct FrameGeometryTests {
    @Test func layoutChecksRejectEmptyFramesAndTouchingEdges() {
        let first = CGRect(x: 0, y: 0, width: 10, height: 10)
        let touching = first.offsetBy(dx: 10, dy: 0)
        #expect(!FrameGeometry.overlaps(first, touching))
        #expect(FrameGeometry.overlaps(first, first.offsetBy(dx: 9, dy: 0)))
        #expect(!FrameGeometry.contains(.zero, in: first))
        #expect(FrameGeometry.contains(first.offsetBy(dx: 1, dy: 0), in: first, tolerance: 1))
        #expect(!FrameGeometry.horizontallyAligned(.zero, first))
        #expect(!FrameGeometry.horizontallyAligned(first, first, tolerance: .nan))
        #expect(!FrameGeometry.horizontallyAligned(first, first, tolerance: 0))
        #expect(!FrameGeometry.horizontallyAligned(first, touching))
        #expect(FrameGeometry.horizontallyAligned(first, first.offsetBy(dx: 0, dy: 10)))
        #expect(!FrameGeometry.contains(first, in: first, tolerance: .nan))
        #expect(FrameGeometry.horizontalGap(between: first, and: first.offsetBy(dx: 15, dy: 0)) == 5)
        #expect(FrameGeometry.horizontalGap(between: touching, and: first) == 0)
        #expect(FrameGeometry.horizontalGap(between: first, and: first.offsetBy(dx: 9, dy: 0)) == 0)
        #expect(FrameGeometry.horizontalGap(between: .zero, and: first) == nil)
    }
}
