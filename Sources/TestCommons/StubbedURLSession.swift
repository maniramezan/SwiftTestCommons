import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A `URLSession` whose requests are answered in process by a caller-supplied handler.
///
/// Each instance routes only its own session's requests, so parallel tests can stub
/// independently, on Apple platforms and Linux alike. Inject
/// ``session`` into the code under test, then inspect ``requests``. Throw a `URLError`
/// from the handler to simulate a transport failure. The handler is asynchronous: await an
/// ``AsyncGate`` to hold a request in flight, or sleep on a ``ManualClock`` to add latency.
/// Cancelling the session task cancels the handler. Uploaded bodies are recorded in
/// `httpBody`. On Linux, FoundationNetworking passes custom protocols only the request
/// itself: the configuration's `httpAdditionalHeaders` and bodies given to `upload(for:from:)`
/// are not visible there. Set headers and `httpBody` on the request for portable tests.
///
/// Up to ``maximumConcurrentSessions`` stubs can be alive at once; creating another
/// throws ``PoolExhausted``; ``init(configuration:waitingForRouteUpTo:handler:)`` waits for
/// a route instead. Keep the stub alive while its session is in use:
/// ``invalidate()`` or deinitialization cancels the session. Its route is released
/// after session invalidation finishes, so outstanding requests cannot reach a replacement stub.
/// Finish using the session before either occurs; invalidated sessions cannot be reused.
/// Unrouted requests fail instead of reaching the network.
///
/// ```swift
/// let stub = try StubbedURLSession(responses: [.json(#"{"id":1}"#), .text("busy", statusCode: 503)])
/// defer { stub.invalidate() }
/// let client = APIClient(session: stub.session)
/// ```
///
/// ## Topics
///
/// ### Creating a session
/// - ``init(configuration:handler:)``
/// - ``init(configuration:waitingForRouteUpTo:handler:)``
/// - ``init(responses:fallback:)``
/// - ``StubResponse``
/// - ``maximumConcurrentSessions``
/// - ``PoolExhausted``
///
/// ### Using the session
/// - ``session``
/// - ``requests``
/// - ``waitForRequests(_:timeout:)``
/// - ``invalidate()``
public final class StubbedURLSession: Sendable {
    /// Thrown when ``maximumConcurrentSessions`` stubs are already alive.
    ///
    /// Invalidate stubs when each test finishes so their routes can be reused.
    public struct PoolExhausted: Error, Equatable {}

    /// The number of stubbed sessions that can route requests at the same time.
    public static var maximumConcurrentSessions: Int { StubURLProtocol.pool.count }

    /// The session to inject into the code under test.
    public let session: URLSession
    private let recorded: TestValueBox<[URLRequest]>
    private let changes: ChangeSignal

    private final class SessionDelegate: NSObject, URLSessionDelegate {
        private let slot: Int
        private let owner: UUID

        init(slot: Int, owner: UUID) {
            self.slot = slot
            self.owner = owner
        }

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
            StubURLProtocol.release(slot, owner: owner)
        }
    }

    /// Creates a session that answers each request with `handler`.
    ///
    /// The handler runs in a task per request; cancelling the request cancels it.
    /// - Parameters:
    ///   - configuration: The base configuration. It is copied, and the copy's protocol
    ///     classes are replaced; the caller's object is not modified.
    ///   - handler: Returns the response for a request, or throws to fail it.
    /// - Throws: ``PoolExhausted`` when too many stubbed sessions are alive.
    public convenience init(
        configuration: URLSessionConfiguration = .ephemeral,
        handler: @escaping @Sendable (URLRequest) async throws -> StubResponse
    ) throws {
        let route = Route(handler)
        guard let slot = StubURLProtocol.acquire(owner: route.owner, route.handler) else {
            throw PoolExhausted()
        }
        self.init(configuration: configuration, route: route, slot: slot)
    }

    /// Creates a session, waiting for a route when ``maximumConcurrentSessions`` are alive.
    ///
    /// Use this from heavily parallel suites where routes are released asynchronously
    /// after other sessions finish invalidating.
    /// - Parameters:
    ///   - configuration: The base configuration; it is copied, not modified.
    ///   - timeout: The real-time budget for a route to become free.
    ///   - handler: Returns the response for a request, or throws to fail it.
    /// - Throws: ``PoolExhausted`` when no route frees up in time, or cancellation.
    public convenience init(
        configuration: URLSessionConfiguration = .ephemeral,
        waitingForRouteUpTo timeout: Duration,
        handler: @escaping @Sendable (URLRequest) async throws -> StubResponse
    ) async throws {
        let route = Route(handler)
        guard
            let slot = try await StubURLProtocol.acquire(
                owner: route.owner, route.handler, waitingUpTo: timeout)
        else {
            throw PoolExhausted()
        }
        self.init(configuration: configuration, route: route, slot: slot)
    }

    private init(configuration: URLSessionConfiguration, route: Route, slot: Int) {
        recorded = route.recorded
        changes = route.changes
        let configuration = (configuration.copy() as? URLSessionConfiguration) ?? .ephemeral
        configuration.protocolClasses = [StubURLProtocol.pool[slot]]
        session = URLSession(
            configuration: configuration,
            delegate: SessionDelegate(slot: slot, owner: route.owner), delegateQueue: nil)
    }

    /// The recording state and routed handler for one session, prepared before claiming a slot.
    private struct Route {
        let owner = UUID()
        let recorded = TestValueBox<[URLRequest]>([])
        let changes = ChangeSignal()
        let handler: StubURLProtocol.Handler

        init(_ handler: @escaping @Sendable (URLRequest) async throws -> StubResponse) {
            let recorded = recorded
            let changes = changes
            self.handler = { request in
                recorded.withValue { $0.append(request) }
                changes.notify()
                return try await handler(request)
            }
        }
    }

    /// Creates a session that answers requests with `responses` in order.
    /// - Parameters:
    ///   - responses: Responses for successive requests.
    ///   - fallback: The response once `responses` is used; `nil` fails later
    ///     requests with `URLError(.resourceUnavailable)`.
    /// - Throws: ``PoolExhausted`` when too many stubbed sessions are alive.
    public convenience init(responses: [StubResponse], fallback: StubResponse? = nil) throws {
        let remaining = TestValueBox(responses[...])
        try self.init { _ in
            if let next = remaining.withValue({ $0.popFirst() }) {
                return next
            }
            guard let fallback else {
                throw URLError(.resourceUnavailable)
            }
            return fallback
        }
    }

    deinit { invalidate() }

    /// The requests received so far in arrival order.
    public var requests: [URLRequest] { recorded.get() }

    /// Waits in real time until at least `count` requests have reached the handler.
    ///
    /// Requests are recorded before the handler runs, so a request held in the
    /// handler counts as received.
    /// - Parameters:
    ///   - count: The nonnegative minimum number of requests.
    ///   - timeout: The real-time observation budget.
    /// - Returns: A snapshot containing at least `count` requests.
    /// - Throws: ``ObservationTimeout`` with the last snapshot, or cancellation.
    public func waitForRequests(_ count: Int, timeout: Duration = .seconds(2)) async throws -> [URLRequest] {
        precondition(count >= 0)
        let recorded = recorded
        return try await changes.observe(
            timeout: timeout, operation: { recorded.get() }, matching: { $0.count >= count })
    }

    /// Cancels outstanding tasks and stops routing requests to the handler.
    ///
    /// Repeat calls are harmless. Deinitialization also cancels the session.
    /// The route becomes reusable after session invalidation finishes.
    public func invalidate() {
        session.invalidateAndCancel()
    }
}
