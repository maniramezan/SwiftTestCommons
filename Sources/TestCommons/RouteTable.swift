import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Slot bookkeeping for stubbed sessions, kept separate from the global pool for testing.
struct RouteTable {
    typealias Handler = @Sendable (URLRequest) throws -> StubResponse
    private struct Route {
        let owner: UUID
        let handler: Handler
    }

    private var routes: [Route?]

    init(capacity: Int) { routes = Array(repeating: nil, count: capacity) }

    mutating func acquire(owner: UUID, _ handler: @escaping Handler) -> Int? {
        guard let slot = routes.firstIndex(where: { $0 == nil }) else { return nil }
        routes[slot] = Route(owner: owner, handler: handler)
        return slot
    }

    // Clears the slot only while `owner` still holds it, so a repeated release after
    // invalidation cannot remove a route that another session has since acquired.
    mutating func release(_ slot: Int, owner: UUID) {
        if routes.indices.contains(slot), routes[slot]?.owner == owner { routes[slot] = nil }
    }

    func handler(for slot: Int) -> Handler? {
        routes.indices.contains(slot) ? routes[slot]?.handler : nil
    }
}
