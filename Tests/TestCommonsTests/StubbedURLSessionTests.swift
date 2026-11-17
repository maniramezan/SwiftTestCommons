import Foundation
import Testing

@testable import TestCommons

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// Pool exhaustion requires exclusive access to the stubs owned by this suite.
@Suite(.serialized)
struct StubbedURLSessionTests {
    private let url: URL

    private final class ReleaseSignal: Sendable {
        let gate: AsyncGate

        init(gate: AsyncGate) { self.gate = gate }

        deinit { gate.open() }
    }

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

    @Test(.timeLimit(.minutes(1)))
    func poolExhaustionThrowsInsteadOfSharingRoutes() async throws {
        var stubs: [StubbedURLSession] = []
        var releases: [AsyncGate] = []
        defer { stubs.forEach { $0.invalidate() } }
        // Earlier tests release their routes asynchronously after invalidation, so wait
        // for those routes too: the pool is only exhausted once this test owns every slot.
        while stubs.count < StubbedURLSession.maximumConcurrentSessions {
            let gate = AsyncGate()
            let signal = ReleaseSignal(gate: gate)
            stubs.append(
                try await StubbedURLSession(waitingForRouteUpTo: .seconds(10)) { _ in
                    withExtendedLifetime(signal) { StubResponse() }
                })
            releases.append(gate)
        }
        #expect(throws: StubbedURLSession.PoolExhausted.self) {
            try StubbedURLSession { _ in StubResponse() }
        }
        await #expect(throws: StubbedURLSession.PoolExhausted.self) {
            try await StubbedURLSession(waitingForRouteUpTo: .milliseconds(10)) { _ in StubResponse() }
        }
        let waiting = Task {
            try await StubbedURLSession(waitingForRouteUpTo: .seconds(30)) { _ in .text("waited") }
        }
        stubs.removeFirst().invalidate()
        let waited = try await waiting.value
        let (data, _) = try await waited.session.data(from: url)
        #expect(String(decoding: data, as: UTF8.self) == "waited")
        waited.invalidate()
        stubs.forEach { $0.invalidate() }
        // Wait for route handlers to be released before another test acquires the pool.
        for gate in releases {
            try await gate.wait()
        }
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

    @Test(arguments: [false, true])
    func endingAStubCancelsRetainedSessionTasksBeforeReusingItsRoute(explicitlyInvalidate: Bool) async throws {
        var first: StubbedURLSession? = try StubbedURLSession { _ in .text("first") }
        let session = try #require(first?.session)
        defer { session.invalidateAndCancel() }
        let registered = AsyncGate()
        let pending = TestValueBox<URLSessionDataTask?>(nil)
        async let result: Data = withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: url) { data, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data ?? Data())
                }
            }
            pending.set(task)
            registered.open()
        }
        try await registered.wait()
        if explicitlyInvalidate {
            first?.invalidate()
        }
        first = nil

        let second = try StubbedURLSession { _ in .text("second") }
        defer { second.invalidate() }
        pending.get()?.resume()
        do {
            _ = try await result
            Issue.record("The old session task should have been cancelled")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        }
        #expect(second.requests.isEmpty)
        let (data, _) = try await second.session.data(from: url)
        #expect(String(decoding: data, as: UTF8.self) == "second")
        #expect(second.requests.count == 1)
    }

    @Test func asyncHandlersCanHoldARequestInFlight() async throws {
        let gate = AsyncGate()
        let stub = try StubbedURLSession { _ in
            try await gate.wait()
            return .text("released")
        }
        defer { stub.invalidate() }
        let session = stub.session
        let url = url
        let response = Task { try await session.data(from: url) }
        let received = try await stub.waitForRequests(1)
        #expect(received.first?.url == url)
        #expect(gate.waiterCount == 1)
        gate.open()
        let (data, _) = try await response.value
        #expect(String(decoding: data, as: UTF8.self) == "released")
    }

    @Test func cancellingARequestCancelsItsHandler() async throws {
        let gate = AsyncGate()
        let cancelled = AsyncGate()
        let stub = try StubbedURLSession { _ in
            do {
                try await gate.wait()
            } catch {
                cancelled.open()
                throw error
            }
            return StubResponse()
        }
        defer { stub.invalidate() }
        let session = stub.session
        let url = url
        let response = Task { try await session.data(from: url) }
        _ = try await stub.waitForRequests(1)
        response.cancel()
        await #expect(throws: (any Error).self) { try await response.value }
        try await cancelled.wait()
    }

    @Test func waitingForMissingRequestsTimesOut() async throws {
        let stub = try StubbedURLSession { _ in StubResponse() }
        defer { stub.invalidate() }
        await #expect(throws: ObservationTimeout<[URLRequest]>.self) {
            try await stub.waitForRequests(1, timeout: .milliseconds(10))
        }
    }
}
