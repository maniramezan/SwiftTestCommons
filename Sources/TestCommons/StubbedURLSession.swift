import Foundation
import Synchronization

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A canned HTTP response returned by a ``StubbedURLSession``.
///
/// ## Topics
///
/// ### Creating responses
/// - ``init(statusCode:headers:body:)``
/// - ``json(_:statusCode:)``
/// - ``text(_:statusCode:)``
///
/// ### Response contents
/// - ``statusCode``
/// - ``headers``
/// - ``body``
public struct StubResponse: Sendable, Equatable {
    /// The HTTP status code.
    public var statusCode: Int
    /// The response header fields.
    public var headers: [String: String]
    /// The response body bytes.
    public var body: Data

    /// Creates a response.
    /// - Parameters:
    ///   - statusCode: The HTTP status code; defaults to 200.
    ///   - headers: The response header fields.
    ///   - body: The response body bytes.
    public init(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// Creates a JSON response with a `Content-Type: application/json` header.
    /// - Parameters:
    ///   - json: The UTF-8 JSON text.
    ///   - statusCode: The HTTP status code; defaults to 200.
    /// - Returns: The response.
    public static func json(_ json: String, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, headers: ["Content-Type": "application/json"], body: Data(json.utf8))
    }

    /// Creates a plain-text response with a `Content-Type: text/plain` header.
    /// - Parameters:
    ///   - text: The UTF-8 body text.
    ///   - statusCode: The HTTP status code; defaults to 200.
    /// - Returns: The response.
    public static func text(_ text: String, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, headers: ["Content-Type": "text/plain"], body: Data(text.utf8))
    }
}

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

// FoundationNetworking gives custom protocols neither the session's headers nor its task,
// so each live stub owns a distinct protocol class; the class identifies the route.
class StubURLProtocol: URLProtocol {
    typealias Handler = RouteTable.Handler
    static let pool: [StubURLProtocol.Type] = [
        StubURLProtocol0.self, StubURLProtocol1.self, StubURLProtocol2.self, StubURLProtocol3.self,
        StubURLProtocol4.self, StubURLProtocol5.self, StubURLProtocol6.self, StubURLProtocol7.self,
        StubURLProtocol8.self, StubURLProtocol9.self, StubURLProtocol10.self, StubURLProtocol11.self,
        StubURLProtocol12.self, StubURLProtocol13.self, StubURLProtocol14.self, StubURLProtocol15.self,
        StubURLProtocol16.self, StubURLProtocol17.self, StubURLProtocol18.self, StubURLProtocol19.self,
        StubURLProtocol20.self, StubURLProtocol21.self, StubURLProtocol22.self, StubURLProtocol23.self,
        StubURLProtocol24.self, StubURLProtocol25.self, StubURLProtocol26.self, StubURLProtocol27.self,
        StubURLProtocol28.self, StubURLProtocol29.self, StubURLProtocol30.self, StubURLProtocol31.self,
        StubURLProtocol32.self, StubURLProtocol33.self, StubURLProtocol34.self, StubURLProtocol35.self,
        StubURLProtocol36.self, StubURLProtocol37.self, StubURLProtocol38.self, StubURLProtocol39.self,
        StubURLProtocol40.self, StubURLProtocol41.self, StubURLProtocol42.self, StubURLProtocol43.self,
        StubURLProtocol44.self, StubURLProtocol45.self, StubURLProtocol46.self, StubURLProtocol47.self,
        StubURLProtocol48.self, StubURLProtocol49.self, StubURLProtocol50.self, StubURLProtocol51.self,
        StubURLProtocol52.self, StubURLProtocol53.self, StubURLProtocol54.self, StubURLProtocol55.self,
        StubURLProtocol56.self, StubURLProtocol57.self, StubURLProtocol58.self, StubURLProtocol59.self,
        StubURLProtocol60.self, StubURLProtocol61.self, StubURLProtocol62.self, StubURLProtocol63.self,
    ]
    private static let routes = Mutex(RouteTable(capacity: pool.count))

    class var slot: Int { -1 }

    static func acquire(owner: UUID, _ handler: @escaping Handler) -> Int? {
        routes.withLock { $0.acquire(owner: owner, handler) }
    }

    static func release(_ slot: Int, owner: UUID) {
        routes.withLock { $0.release(slot, owner: owner) }
    }

    static func handler(for slot: Int) -> Handler? {
        routes.withLock { $0.handler(for: slot) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler(for: type(of: self).slot) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let stub = try handler(Self.recordable(request))
            guard
                let url = request.url,
                let response = HTTPURLResponse(
                    url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !stub.body.isEmpty { client?.urlProtocol(self, didLoad: stub.body) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func recordable(_ request: URLRequest) -> URLRequest {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            copy.httpBodyStream = nil
            copy.httpBody = read(stream)
        }
        return copy
    }

    static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class StubURLProtocol0: StubURLProtocol { override class var slot: Int { 0 } }
final class StubURLProtocol1: StubURLProtocol { override class var slot: Int { 1 } }
final class StubURLProtocol2: StubURLProtocol { override class var slot: Int { 2 } }
final class StubURLProtocol3: StubURLProtocol { override class var slot: Int { 3 } }
final class StubURLProtocol4: StubURLProtocol { override class var slot: Int { 4 } }
final class StubURLProtocol5: StubURLProtocol { override class var slot: Int { 5 } }
final class StubURLProtocol6: StubURLProtocol { override class var slot: Int { 6 } }
final class StubURLProtocol7: StubURLProtocol { override class var slot: Int { 7 } }
final class StubURLProtocol8: StubURLProtocol { override class var slot: Int { 8 } }
final class StubURLProtocol9: StubURLProtocol { override class var slot: Int { 9 } }
final class StubURLProtocol10: StubURLProtocol { override class var slot: Int { 10 } }
final class StubURLProtocol11: StubURLProtocol { override class var slot: Int { 11 } }
final class StubURLProtocol12: StubURLProtocol { override class var slot: Int { 12 } }
final class StubURLProtocol13: StubURLProtocol { override class var slot: Int { 13 } }
final class StubURLProtocol14: StubURLProtocol { override class var slot: Int { 14 } }
final class StubURLProtocol15: StubURLProtocol { override class var slot: Int { 15 } }
final class StubURLProtocol16: StubURLProtocol { override class var slot: Int { 16 } }
final class StubURLProtocol17: StubURLProtocol { override class var slot: Int { 17 } }
final class StubURLProtocol18: StubURLProtocol { override class var slot: Int { 18 } }
final class StubURLProtocol19: StubURLProtocol { override class var slot: Int { 19 } }
final class StubURLProtocol20: StubURLProtocol { override class var slot: Int { 20 } }
final class StubURLProtocol21: StubURLProtocol { override class var slot: Int { 21 } }
final class StubURLProtocol22: StubURLProtocol { override class var slot: Int { 22 } }
final class StubURLProtocol23: StubURLProtocol { override class var slot: Int { 23 } }
final class StubURLProtocol24: StubURLProtocol { override class var slot: Int { 24 } }
final class StubURLProtocol25: StubURLProtocol { override class var slot: Int { 25 } }
final class StubURLProtocol26: StubURLProtocol { override class var slot: Int { 26 } }
final class StubURLProtocol27: StubURLProtocol { override class var slot: Int { 27 } }
final class StubURLProtocol28: StubURLProtocol { override class var slot: Int { 28 } }
final class StubURLProtocol29: StubURLProtocol { override class var slot: Int { 29 } }
final class StubURLProtocol30: StubURLProtocol { override class var slot: Int { 30 } }
final class StubURLProtocol31: StubURLProtocol { override class var slot: Int { 31 } }
final class StubURLProtocol32: StubURLProtocol { override class var slot: Int { 32 } }
final class StubURLProtocol33: StubURLProtocol { override class var slot: Int { 33 } }
final class StubURLProtocol34: StubURLProtocol { override class var slot: Int { 34 } }
final class StubURLProtocol35: StubURLProtocol { override class var slot: Int { 35 } }
final class StubURLProtocol36: StubURLProtocol { override class var slot: Int { 36 } }
final class StubURLProtocol37: StubURLProtocol { override class var slot: Int { 37 } }
final class StubURLProtocol38: StubURLProtocol { override class var slot: Int { 38 } }
final class StubURLProtocol39: StubURLProtocol { override class var slot: Int { 39 } }
final class StubURLProtocol40: StubURLProtocol { override class var slot: Int { 40 } }
final class StubURLProtocol41: StubURLProtocol { override class var slot: Int { 41 } }
final class StubURLProtocol42: StubURLProtocol { override class var slot: Int { 42 } }
final class StubURLProtocol43: StubURLProtocol { override class var slot: Int { 43 } }
final class StubURLProtocol44: StubURLProtocol { override class var slot: Int { 44 } }
final class StubURLProtocol45: StubURLProtocol { override class var slot: Int { 45 } }
final class StubURLProtocol46: StubURLProtocol { override class var slot: Int { 46 } }
final class StubURLProtocol47: StubURLProtocol { override class var slot: Int { 47 } }
final class StubURLProtocol48: StubURLProtocol { override class var slot: Int { 48 } }
final class StubURLProtocol49: StubURLProtocol { override class var slot: Int { 49 } }
final class StubURLProtocol50: StubURLProtocol { override class var slot: Int { 50 } }
final class StubURLProtocol51: StubURLProtocol { override class var slot: Int { 51 } }
final class StubURLProtocol52: StubURLProtocol { override class var slot: Int { 52 } }
final class StubURLProtocol53: StubURLProtocol { override class var slot: Int { 53 } }
final class StubURLProtocol54: StubURLProtocol { override class var slot: Int { 54 } }
final class StubURLProtocol55: StubURLProtocol { override class var slot: Int { 55 } }
final class StubURLProtocol56: StubURLProtocol { override class var slot: Int { 56 } }
final class StubURLProtocol57: StubURLProtocol { override class var slot: Int { 57 } }
final class StubURLProtocol58: StubURLProtocol { override class var slot: Int { 58 } }
final class StubURLProtocol59: StubURLProtocol { override class var slot: Int { 59 } }
final class StubURLProtocol60: StubURLProtocol { override class var slot: Int { 60 } }
final class StubURLProtocol61: StubURLProtocol { override class var slot: Int { 61 } }
final class StubURLProtocol62: StubURLProtocol { override class var slot: Int { 62 } }
final class StubURLProtocol63: StubURLProtocol { override class var slot: Int { 63 } }
