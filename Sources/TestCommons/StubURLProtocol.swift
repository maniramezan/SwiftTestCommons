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
            if !stub.body.isEmpty {
                client?.urlProtocol(self, didLoad: stub.body)
            }
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
