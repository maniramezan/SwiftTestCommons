import Foundation
import Testing
import TestCommons
#if canImport(CoreGraphics)
    import CoreGraphics
#endif

struct FixtureValuesTests {
    @Test func environmentOverridesDoNotMutateTheirBase() {
        let base = ["KEEP": "yes", "REMOVE": "old"]
        let result = fixtureEnvironment(base: base, overrides: ["REMOVE": nil, "ADD": "new"])
        #expect(result == ["KEEP": "yes", "ADD": "new"])
        #expect(base["REMOVE"] == "old")
    }

    @Test func roundTripUsesCallerDatePolicy() throws {
        struct Fixture: Codable, Equatable { let date: Date }
        let fixture = Fixture(date: Date(timeIntervalSince1970: 1.125))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        #expect(try jsonRoundTrip(fixture, encoder: encoder, decoder: decoder) == fixture)
    }

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
