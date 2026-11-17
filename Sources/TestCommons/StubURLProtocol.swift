import Foundation
import Synchronization

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

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
    /// Notified whenever a route is released, so waiting sessions can claim it.
    static let releases = ChangeSignal()
    private let loading = Mutex<Task<Void, Never>?>(nil)

    /// Carries the protocol instance into its loading task.
    ///
    /// URLProtocol is not Sendable, but URL loading tolerates client callbacks from any
    /// thread, and `stopLoading` cancels the task before the instance is released. A
    /// `nonisolated(unsafe)` local is not enough: Swift 6.2 still rejects the capture.
    private struct UncheckedInstance: @unchecked Sendable {
        let value: StubURLProtocol
    }

    class var slot: Int { -1 }

    static func acquire(owner: UUID, _ handler: @escaping Handler) -> Int? {
        routes.withLock { $0.acquire(owner: owner, handler) }
    }

    static func release(_ slot: Int, owner: UUID) {
        routes.withLock { $0.release(slot, owner: owner) }
        releases.notify()
    }

    /// Claims a route, waiting up to `timeout` for another session to release one.
    static func acquire(owner: UUID, _ handler: @escaping Handler, waitingUpTo timeout: Duration) async throws
        -> Int?
    {
        do {
            return try await releases.observe(
                timeout: timeout, operation: { acquire(owner: owner, handler) }, matching: { $0 != nil })
        } catch is ObservationTimeout<Int?> {
            return nil
        }
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
        let request = Self.recordable(request)
        let instance = UncheckedInstance(value: self)
        let task = Task {
            let outcome: Result<StubResponse, any Error>
            do {
                outcome = .success(try await handler(request))
            } catch {
                outcome = .failure(error)
            }
            guard !Task.isCancelled else { return }
            instance.value.deliver(outcome, for: request)
        }
        loading.withLock { $0 = task }
    }

    override func stopLoading() {
        loading.withLock { task in
            task?.cancel()
            task = nil
        }
    }

    private func deliver(_ outcome: Result<StubResponse, any Error>, for request: URLRequest) {
        switch outcome {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .success(let stub):
            guard
                let url = request.url,
                let response = HTTPURLResponse(
                    url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !stub.body.isEmpty {
                client?.urlProtocol(self, didLoad: stub.body)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

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
