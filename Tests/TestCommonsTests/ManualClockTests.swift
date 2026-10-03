import Foundation
import Testing

@testable import TestCommons

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
