import Foundation
import Testing
import TestCommons

struct AsyncGateTests {
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
}
