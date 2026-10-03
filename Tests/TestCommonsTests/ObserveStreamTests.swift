import Foundation
import Testing
import TestCommons

struct ObserveStreamTests {
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

    @Test func throwingStreamCollectsUntilItsLimit() async throws {
        let stream = AsyncThrowingStream<Int, any Error> {
            $0.yield(1); $0.yield(2); $0.finish()
        }
        let result = try await observeStream(stream, maxCount: 1, timeout: .seconds(2))
        #expect(result.values == [1])
        #expect(result.end == .limitReached)
    }

    @Test func timeoutFinishesTheSourceButLimitsDoNot() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.yield(1)
        #expect(try await observeStream(stream, maxCount: 1, timeout: .seconds(2)).end == .limitReached)
        continuation.yield(2)
        #expect(try await observeStream(stream, maxCount: 1, timeout: .seconds(2)).values == [2])
        #expect(try await observeStream(stream, maxCount: 1, timeout: .milliseconds(20)).end == .timedOut)
        continuation.yield(3)
        let afterTimeout = try await observeStream(stream, maxCount: 1, timeout: .seconds(2))
        #expect(afterTimeout.values.isEmpty)
        #expect(afterTimeout.end == .finished)
    }

    @Test func zeroBudgetsConsumeNothing() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.yield(1)
        #expect(try await observeStream(stream, maxCount: 0, timeout: .seconds(2)).end == .limitReached)
        let timedOut = try await observeStream(stream, maxCount: 1, timeout: .zero)
        #expect(timedOut.values.isEmpty)
        #expect(timedOut.end == .timedOut)
        #expect(try await observeStream(stream, maxCount: 1, timeout: .seconds(2)).values == [1])
    }

    @Test func cancelledStreamObservationFinishes() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let task = Task { try await observeStream(stream, maxCount: 1, timeout: .seconds(60)) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
