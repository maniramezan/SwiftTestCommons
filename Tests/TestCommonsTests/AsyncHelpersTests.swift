import Foundation
import Testing
import TestCommons

struct AsyncHelpersTests {
    @Test func gateSupportsMultipleWaitersAndEarlyOpening() async throws {
        let gate = AsyncGate()
        let first = Task { try await gate.wait() }
        let second = Task { try await gate.wait() }
        _ = try await waitUntil(timeout: .seconds(2), operation: { gate.waiterCount }, matching: { $0 == 2 })
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(gate.waiterCount == 1)
        gate.open()
        gate.open()
        try await second.value
        try await gate.wait()
        #expect(gate.waiterCount == 0)
    }

    @Test func alreadyCancelledGateWaitDoesNotLeak() async {
        let gate = AsyncGate()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await gate.wait()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(gate.waiterCount == 0)
    }

    @Test func timeoutIncludesLastObservation() async {
        do {
            _ = try await waitUntil(timeout: .zero, operation: { 42 }, matching: { $0 == 0 })
            Issue.record("Expected timeout")
        } catch let error as ObservationTimeout<Int> {
            #expect(error.lastObservation == 42)
        } catch { Issue.record(error) }
    }

    @Test func streamDeadlineReturnsPartialValues() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.yield(1)
        let result = try await observeStream(stream, maxCount: 2, timeout: .milliseconds(50))
        #expect(result.values == [1])
        #expect(result.end == .timedOut)
    }

    @Test func streamsDistinguishFinishLimitAndMatch() async throws {
        func stream() -> AsyncStream<Int> {
            AsyncStream {
                $0.yield(1); $0.yield(2); $0.finish()
            }
        }
        let finished = try await observeStream(stream(), maxCount: 3, timeout: .seconds(2))
        #expect(finished.end == .finished)
        let limited = try await observeStream(stream(), maxCount: 1, timeout: .seconds(2))
        #expect(limited.values == [1])
        #expect(limited.end == .limitReached)
        let matched = try await observeStream(stream(), maxCount: 3, timeout: .seconds(2), until: { $0 == 2 })
        #expect(matched.values == [1, 2])
        #expect(matched.end == .matched)
    }

    @Test func throwingStreamPropagatesError() async {
        let stream = AsyncThrowingStream<Int, any Error> { $0.finish(throwing: TestError()) }
        await #expect(throws: TestError()) {
            try await observeStream(stream, maxCount: 1, timeout: .seconds(2))
        }
    }

    @Test func cancelledStreamObservationFinishes() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let task = Task { try await observeStream(stream, maxCount: 1, timeout: .seconds(60)) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func recorderWaitsAndResets() async throws {
        let recorder = CallRecorder<Int>()
        let waiting = Task { try await recorder.waitForCount(2, timeout: .seconds(2)) }
        await recorder.record(1)
        await recorder.record(2)
        #expect(try await waiting.value == [1, 2])
        await recorder.reset()
        #expect(await recorder.count == 0)
    }

    @Test func fixtureFilesAreContainedAndDecodeUTF8() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let file = try directory.write(Data("hello".utf8), named: "nested/sample.txt")
        #expect(file.lastPathComponent == "sample.txt")
        let fixtures = FixtureDirectory(root: directory.url)
        #expect(try fixtures.text(named: "nested/sample.txt") == "hello")
        #expect(throws: CocoaError.self) { try fixtures.data(named: "../outside") }
        #expect(throws: CocoaError.self) { try directory.write(Data(), named: "../outside") }
        #expect(throws: CocoaError.self) { try fixtures.data(named: "missing") }
    }

    @Test func scriptsHaveExplicitExhaustion() throws {
        var failing = ScriptedValues([1])
        #expect(try failing.next() == 1)
        #expect(throws: TestError()) { try failing.next() }
        var repeating = ScriptedValues([1, 2], exhaustion: .repeatLast)
        #expect(try repeating.next() == 1)
        #expect(try repeating.next() == 2)
        #expect(try repeating.next() == 2)
        var fallback = ScriptedValues<Int>([], exhaustion: .fallback(3))
        #expect(try fallback.next() == 3)
    }
}
