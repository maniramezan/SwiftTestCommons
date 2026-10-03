import Foundation
import Testing

@testable import TestCommons

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct ManualClockTests {
    @Test func pastAndPresentDeadlinesReturnImmediately() async throws {
        let clock = ManualClock()
        try await clock.sleep(until: clock.now)
        try await clock.sleep(for: .zero)
        #expect(clock.now.offset == .zero)
        #expect(clock.minimumResolution == .zero)
    }

    @Test func advancingResumesDueSleepersOnly() async throws {
        let clock = ManualClock()
        let order = TestValueBox<[Int]>([])
        let short = Task {
            try await clock.sleep(for: .seconds(1))
            order.withValue { $0.append(1) }
        }
        let long = Task {
            try await clock.sleep(for: .seconds(5))
            order.withValue { $0.append(5) }
        }
        try await clock.waitForSleepers(2)
        clock.advance(by: .seconds(2))
        try await short.value
        #expect(order.get() == [1])
        #expect(clock.sleeperCount == 1)
        clock.advance(to: clock.now.advanced(by: .seconds(3)))
        try await long.value
        #expect(order.get() == [1, 5])
        #expect(clock.now.offset == .seconds(5))
    }

    @Test func movingToAnEarlierInstantKeepsTime() {
        let clock = ManualClock()
        clock.advance(by: .seconds(3))
        clock.advance(to: ManualClock.Instant(offset: .seconds(1)))
        #expect(clock.now.offset == .seconds(3))
    }

    @Test func cancellationRemovesOnlyTheCancelledSleeper() async throws {
        let clock = ManualClock()
        let cancelled = Task { try await clock.sleep(for: .seconds(1)) }
        let kept = Task { try await clock.sleep(for: .seconds(1)) }
        try await clock.waitForSleepers(2)
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(clock.sleeperCount == 1)
        clock.advance(by: .seconds(1))
        try await kept.value
    }

    @Test func alreadyCancelledSleepThrows() async {
        let clock = ManualClock()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await clock.sleep(for: .seconds(1))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(clock.sleeperCount == 0)
    }

    @Test func waitingForMissingSleepersTimesOut() async {
        await #expect(throws: ObservationTimeout<Int>.self) {
            try await ManualClock().waitForSleepers(1, timeout: .milliseconds(10))
        }
    }

    @Test func instantsMeasureManualTime() {
        let start = ManualClock.Instant(offset: .seconds(1))
        let later = start.advanced(by: .milliseconds(500))
        #expect(start < later)
        #expect(start.duration(to: later) == .milliseconds(500))
        #expect(later.duration(to: start) == .milliseconds(-500))
    }
}

struct ScriptedResponderTests {
    @Test func answersCallsInOrderAndRecordsRequests() async throws {
        let responder = ScriptedResponder<String, Int>([.success(1), .failure(TestError())])
        #expect(try await responder.respond(to: "a") == 1)
        await #expect(throws: TestError()) { try await responder.respond(to: "b") }
        await #expect(throws: ScriptedResponder<String, Int>.Exhausted(callIndex: 2)) {
            try await responder.respond(to: "c")
        }
        #expect(await responder.requests == ["a", "b", "c"])
        #expect(await responder.callCount == 3)
    }

    @Test func fallbackAnswersAfterTheScript() async throws {
        let responder = ScriptedResponder<Int, String>([], fallback: .success("default"))
        #expect(try await responder.respond(to: 1) == "default")
        #expect(try await responder.respond(to: 2) == "default")
    }

    @Test func aHeldCallKeepsItsOwnOutcome() async throws {
        let responder = ScriptedResponder<String, Int>([.success(0), .success(1)])
        let gate = await responder.hold(call: 0)
        #expect(await responder.hold(call: 0) === gate)
        let first = Task { try await responder.respond(to: "first") }
        _ = try await responder.waitForCalls(1)
        #expect(try await responder.respond(to: "second") == 1)
        gate.open()
        #expect(try await first.value == 0)
        #expect(await responder.requests == ["first", "second"])
    }

    @Test func cancellingAHeldCallThrows() async throws {
        let responder = ScriptedResponder<Int, Int>([.success(0)])
        _ = await responder.hold(call: 0)
        let call = Task { try await responder.respond(to: 7) }
        _ = try await responder.waitForCalls(1)
        call.cancel()
        await #expect(throws: CancellationError.self) { try await call.value }
    }

    @Test func waitingForMissingCallsTimesOut() async {
        let responder = ScriptedResponder<Int, Int>([])
        await #expect(throws: ObservationTimeout<[Int]>.self) {
            try await responder.waitForCalls(1, timeout: .milliseconds(10))
        }
    }
}

struct StubbedURLSessionTests {
    private let url = URL(string: "https://example.test/items?page=1")!

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

    @Test func routeTablesAreBoundedReuseSlotsAndIgnoreStaleReleases() throws {
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

    @Test func everyPooledProtocolRoutesItsOwnSlot() {
        #expect(StubURLProtocol.slot == -1)
        #expect(StubURLProtocol.pool.enumerated().allSatisfy { index, type in type.slot == index })
        #expect(Set(StubURLProtocol.pool.map { ObjectIdentifier($0) }).count == StubURLProtocol.pool.count)
    }

    @Test func unroutedRequestsFailInsteadOfReachingTheNetwork() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        await #expect {
            try await session.data(from: url)
        } throws: { error in
            (error as? URLError)?.code == .unsupportedURL
        }
    }

    @Test func streamedBodiesAreRecordedAsData() {
        let request = URLRequest(url: url)
        let streamed = StubURLProtocol.recordable(
            {
                var copy = request
                copy.httpBodyStream = InputStream(data: Data("streamed".utf8))
                return copy
            }())
        #expect(streamed.httpBody == Data("streamed".utf8))
        #expect(StubURLProtocol.read(InputStream(data: Data())).isEmpty)
    }
}

struct TemporaryDirectoryPrefixTests {
    @Test func prefixLabelsTheDirectory() throws {
        let directory = try TemporaryDirectory(prefix: "LoginTests")
        defer { try? directory.remove() }
        #expect(directory.url.lastPathComponent.hasPrefix("LoginTests-"))
        #expect(FileManager.default.fileExists(atPath: directory.url.path))
    }

    @Test(arguments: ["", "a/b", ".", ".."])
    func unusablePrefixesAreRejected(prefix: String) {
        #expect(throws: CocoaError.self) { try TemporaryDirectory(prefix: prefix) }
    }
}
