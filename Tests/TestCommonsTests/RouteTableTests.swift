import Foundation
import Testing

@testable import TestCommons

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct RouteTableTests {
    private let url: URL

    init() throws {
        url = try #require(URL(string: "https://example.test/items?page=1"))
    }

    @Test func tablesAreBoundedReuseSlotsAndIgnoreStaleReleases() throws {
        var table = RouteTable(capacity: 2)
        let first = UUID()
        let second = UUID()
        let third = UUID()
        #expect(table.acquire(owner: first) { _ in .text("first") } == 0)
        #expect(table.acquire(owner: second) { _ in .text("second") } == 1)
        #expect(table.acquire(owner: third) { _ in .text("third") } == nil)
        table.release(0, owner: first)
        #expect(table.acquire(owner: third) { _ in .text("third") } == 0)
        table.release(0, owner: first)
        table.release(7, owner: third)
        let handler = try #require(table.handler(for: 0))
        #expect(try handler(URLRequest(url: url)) == .text("third"))
        #expect(table.handler(for: -1) == nil)
        #expect(StubbedURLSession.maximumConcurrentSessions == 64)
        #expect(StubbedURLSession.PoolExhausted() == StubbedURLSession.PoolExhausted())
    }
}
