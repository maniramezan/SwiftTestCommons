import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A `URLSession` whose requests are answered in process by a caller-supplied handler.
///
/// Each instance routes only its own session's requests, so parallel tests can stub
/// independently without global state, on Apple platforms and Linux alike. Inject
/// ``session`` into the code under test, then inspect ``requests``. Throw a `URLError`
/// from the handler to simulate a transport failure. Uploaded bodies are recorded in
/// `httpBody`. On Linux, FoundationNetworking passes custom protocols only the request
/// itself: the configuration's `httpAdditionalHeaders` and bodies given to `upload(for:from:)`
/// are not visible there. Set headers and `httpBody` on the request for portable tests.
///
/// Up to ``maximumConcurrentSessions`` stubs can be alive at once; creating another
/// throws ``PoolExhausted``. Keep the stub alive while its session is in use:
/// ``invalidate()`` or deinitialization stops routing, and unrouted requests fail with
/// `URLError(.unsupportedURL)` instead of reaching the network.
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
/// - ``init(responses:fallback:)``
/// - ``StubResponse``
/// - ``maximumConcurrentSessions``
/// - ``PoolExhausted``
///
/// ### Using the session
/// - ``session``
/// - ``requests``
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
    private let slot: Int
    private let owner = UUID()
    private let recorded = TestValueBox<[URLRequest]>([])

    /// Creates a session that answers each request with `handler`.
    ///
    /// The handler runs on a URL-loading thread; keep it synchronous and short.
    /// - Parameters:
    ///   - configuration: The base configuration. It is copied, and the copy's protocol
    ///     classes are replaced; the caller's object is not modified.
    ///   - handler: Returns the response for a request, or throws to fail it.
    /// - Throws: ``PoolExhausted`` when too many stubbed sessions are alive.
    public init(
        configuration: URLSessionConfiguration = .ephemeral,
        handler: @escaping @Sendable (URLRequest) throws -> StubResponse
    ) throws {
        let recorded = recorded
        let route: StubURLProtocol.Handler = { request in
            recorded.withValue { $0.append(request) }
            return try handler(request)
        }
        guard let slot = StubURLProtocol.acquire(owner: owner, route) else { throw PoolExhausted() }
        self.slot = slot
        let configuration = (configuration.copy() as? URLSessionConfiguration) ?? .ephemeral
        configuration.protocolClasses = [StubURLProtocol.pool[slot]]
        session = URLSession(configuration: configuration)
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
            if let next = remaining.withValue({ $0.popFirst() }) { return next }
            guard let fallback else { throw URLError(.resourceUnavailable) }
            return fallback
        }
    }

    deinit { StubURLProtocol.release(slot, owner: owner) }

    /// The requests received so far in arrival order.
    public var requests: [URLRequest] { recorded.get() }

    /// Cancels outstanding tasks and stops routing requests to the handler.
    ///
    /// Repeat calls are harmless. Deinitialization also stops routing.
    public func invalidate() {
        StubURLProtocol.release(slot, owner: owner)
        session.invalidateAndCancel()
    }
}
