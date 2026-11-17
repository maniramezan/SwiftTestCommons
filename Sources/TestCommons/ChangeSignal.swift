import Foundation
import Synchronization

/// Wakes observers when guarded state changes, so count waits need no polling.
///
/// Owners call ``notify()`` after every mutation an observer may care about. Observers
/// read ``generation`` before checking the state, then wait for a later generation, so a
/// change that lands between the check and the wait is never missed.
final class ChangeSignal: Sendable {
    private struct State {
        var generation = 0
        var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    }
    private let state = Mutex(State())

    /// Increases on every ``notify()``.
    var generation: Int { state.withLock { $0.generation } }

    /// The number of suspended observers.
    var waiterCount: Int { state.withLock { $0.waiters.count } }

    /// Records a change and resumes every observer.
    func notify() {
        let waiters = state.withLock { state in
            state.generation += 1
            let waiters = Array(state.waiters.values)
            state.waiters.removeAll()
            return waiters
        }
        for waiter in waiters { waiter.resume() }
    }

    /// Waits until a change after `generation`, or until `timeout` passes.
    /// - Returns: `true` after a change; `false` when the timeout expires first.
    func wait(since generation: Int, timeout: Duration) async throws -> Bool {
        guard timeout > .zero else { return self.generation != generation }
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await self.waitForChange(since: generation)
                return true
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return false
            }
            defer { group.cancelAll() }
            // The group always holds both tasks here, so `next()` returns a value.
            return try await group.next() ?? false
        }
    }

    /// Reads state until it matches, waking on each change instead of polling.
    ///
    /// The deadline is monotonic. One observation is made even for a zero timeout, and a
    /// final observation is made when the deadline expires.
    func observe<Value: Sendable>(
        timeout: Duration,
        operation: @Sendable () async throws -> Value,
        matching predicate: @Sendable (Value) -> Bool
    ) async throws -> Value {
        precondition(timeout >= .zero)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while true {
            try Task.checkCancellation()
            let observed = generation
            let value = try await operation()
            if predicate(value) { return value }
            let remaining = clock.now.duration(to: deadline)
            guard remaining > .zero, try await wait(since: observed, timeout: remaining) else {
                let last = try await operation()
                if predicate(last) { return last }
                throw ObservationTimeout(lastObservation: last)
            }
        }
    }

    private func waitForChange(since generation: Int) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome: Int = state.withLock { state in
                    if Task.isCancelled { return 1 }
                    if state.generation != generation { return 2 }
                    state.waiters[id] = continuation
                    return 0
                }
                if outcome == 1 {
                    continuation.resume(throwing: CancellationError())
                }
                if outcome == 2 {
                    continuation.resume()
                }
            }
        } onCancel: {
            let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
            waiter?.resume(throwing: CancellationError())
        }
    }
}
