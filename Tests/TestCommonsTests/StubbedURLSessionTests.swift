import Foundation
import Testing

@testable import TestCommons

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct StubbedURLSessionTests {
    private let url: URL

    init() throws {
        url = try #require(URL(string: "https://example.test/items?page=1"))
    }

    @Test func scriptedResponsesAreReturnedInOrder() async throws {
        let stub = try StubbedURLSession(responses: [.json(#"{"id":1}"#), .text("busy", statusCode: 503)])
        defer { stub.invalidate() }
        let (first, firstResponse) = try await stub.session.data(from: url)
        #expect(String(decoding: first, as: UTF8.self) == #"{"id":1}"#)
        let http = try #require(firstResponse as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let (second, secondResponse) = try await stub.session.data(from: url)
        #expect(String(decoding: second, as: UTF8.self) == "busy")
        #expect((secondResponse as? HTTPURLResponse)?.statusCode == 503)
        await #expect(throws: URLError.self) { try await stub.session.data(from: url) }
        #expect(stub.requests.count == 3)
    }

    @Test func fallbackAndEmptyBodiesAreSupported() async throws {
        let stub = try StubbedURLSession(responses: [], fallback: StubResponse(statusCode: 204))
        defer { stub.invalidate() }
        let (data, response) = try await stub.session.data(from: url)
        #expect(data.isEmpty)
        #expect((response as? HTTPURLResponse)?.statusCode == 204)
    }

    @Test func recordedRequestsKeepHeadersAndBodies() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["X-Client": "tests"]
        let stub = try StubbedURLSession(configuration: configuration) { request in
            .text(request.httpMethod ?? "")
        }
        defer { stub.invalidate() }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("payload".utf8)
        _ = try await stub.session.data(for: request)
        let recorded = try #require(stub.requests.first)
        #expect(recorded.httpMethod == "POST")
        #expect(recorded.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(recorded.httpBody == Data("payload".utf8))
        #if !canImport(FoundationNetworking)
            // FoundationNetworking does not expose session-level headers to custom protocols.
            #expect(recorded.value(forHTTPHeaderField: "X-Client") == "tests")
        #endif
        #expect(!(configuration.protocolClasses ?? []).contains { $0 is StubURLProtocol.Type })
    }

    #if !canImport(FoundationNetworking)
        // FoundationNetworking keeps upload-task bodies on the task, out of custom protocols' reach.
        @Test func uploadTaskBodiesAreRecorded() async throws {
            let stub = try StubbedURLSession { _ in StubResponse() }
            defer { stub.invalidate() }
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            _ = try await stub.session.upload(for: request, from: Data("payload".utf8))
            #expect(stub.requests.first?.httpBody == Data("payload".utf8))
        }
    #endif

    @Test func handlerErrorsFailTheRequest() async throws {
        let stub = try StubbedURLSession { _ in throw URLError(.timedOut) }
        defer { stub.invalidate() }
        await #expect {
            try await stub.session.data(from: url)
        } throws: { error in
            (error as? URLError)?.code == .timedOut
        }
    }

    @Test func concurrentSessionsAreIsolated() async throws {
        let stubs = try (0..<8).map { index in try StubbedURLSession { _ in .text("\(index)") } }
        defer { stubs.forEach { $0.invalidate() } }
        let bodies = try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, stub) in stubs.enumerated() {
                group.addTask { [url] in
                    let (data, _) = try await stub.session.data(from: url)
                    return (index, String(decoding: data, as: UTF8.self))
                }
            }
            return try await group.reduce(into: [Int: String]()) { $0[$1.0] = $1.1 }
        }
        #expect(bodies == Dictionary(uniqueKeysWithValues: (0..<8).map { ($0, "\($0)") }))
        #expect(stubs.allSatisfy { $0.requests.count == 1 })
    }

    @Test func releasingAnInvalidatedStubAgainKeepsTheNextOwnersRoute() async throws {
        var first: StubbedURLSession? = try StubbedURLSession { _ in .text("first") }
        first?.invalidate()
        let second = try StubbedURLSession { _ in .text("second") }
        defer { second.invalidate() }
        // Deinitializing the invalidated stub releases its slot a second time.
        first = nil
        let (data, _) = try await second.session.data(from: url)
        #expect(String(decoding: data, as: UTF8.self) == "second")
    }
}
