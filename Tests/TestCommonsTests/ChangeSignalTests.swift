import Testing

@testable import TestCommons

struct ChangeSignalTests {
    @Test func aChangeBeforeWaitingIsNotMissed() async throws {
        let signal = ChangeSignal()
        let observed = signal.generation
        signal.notify()
        #expect(try await signal.wait(since: observed, timeout: .seconds(5)))
        #expect(signal.waiterCount == 0)
    }

    @Test func waitersWakeOnTheNextChange() async throws {
        let signal = ChangeSignal()
        let observed = signal.generation
        let waiting = Task { try await signal.wait(since: observed, timeout: .seconds(5)) }
        while signal.waiterCount == 0 { await Task.yield() }
        signal.notify()
        #expect(try await waiting.value)
    }

    @Test func timeoutsReportNoChange() async throws {
        let signal = ChangeSignal()
        #expect(try await signal.wait(since: signal.generation, timeout: .zero) == false)
        #expect(try await signal.wait(since: signal.generation, timeout: .milliseconds(10)) == false)
        #expect(signal.waiterCount == 0)
    }

    @Test func cancellationRemovesTheWaiter() async throws {
        let signal = ChangeSignal()
        let waiting = Task { try await signal.wait(since: signal.generation, timeout: .seconds(30)) }
        while signal.waiterCount == 0 { await Task.yield() }
        waiting.cancel()
        await #expect(throws: CancellationError.self) { try await waiting.value }
        #expect(signal.waiterCount == 0)
    }

    @Test func observationMakesAFinalReadAtTheDeadline() async throws {
        let signal = ChangeSignal()
        let value = TestValueBox(0)
        await #expect(throws: ObservationTimeout<Int>.self) {
            try await signal.observe(timeout: .milliseconds(10), operation: { value.get() }, matching: { $0 > 0 })
        }
        let waiting = Task {
            try await signal.observe(timeout: .seconds(5), operation: { value.get() }, matching: { $0 == 2 })
        }
        value.set(1)
        signal.notify()
        value.set(2)
        signal.notify()
        #expect(try await waiting.value == 2)
    }

    @Test func aChangeWithoutNotificationIsCaughtByTheFinalRead() async throws {
        let signal = ChangeSignal()
        let reads = TestValueBox(0)
        let value = try await signal.observe(
            timeout: .milliseconds(10),
            operation: {
                reads.withValue { count in
                    count += 1
                    return count
                }
            },
            matching: { $0 >= 2 })
        #expect(value == 2)
    }

    @Test func alreadyCancelledWaitsThrowWithoutRegistering() async {
        let signal = ChangeSignal()
        let waiting = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await signal.wait(since: signal.generation, timeout: .seconds(30))
        }
        await #expect(throws: CancellationError.self) { try await waiting.value }
        #expect(signal.waiterCount == 0)
    }
}
