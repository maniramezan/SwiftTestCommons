import Foundation
import Synchronization

/// A one-shot signal that resumes every waiter when opened.
///
/// Cancellation removes only the cancelled waiter. Opening is repeatable, and
/// future waits return immediately. No task is created to deliver cancellation.
///
/// ## Topics
/// - ``init()``
/// - ``wait()``
/// - ``open()``
/// - ``waiterCount``
public final class AsyncGate: Sendable {
    private struct State {
        var isOpen = false
        var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    }
    private let state = Mutex(State())

    /// Creates a closed gate.
    public init() {}

    /// The number of suspended callers, useful for establishing test interleavings.
    public var waiterCount: Int { state.withLock { $0.waiters.count } }

    /// Suspends until opened, or throws when the calling task is cancelled.
    /// - Throws: `CancellationError` if cancellation wins registration or delivery.
    public func wait() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let outcome: Int = state.withLock { state in
                    if Task.isCancelled {
                        return 1
                    }
                    if state.isOpen {
                        return 2
                    }
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
        try Task.checkCancellation()
    }

    /// Opens the gate permanently and resumes all registered callers.
    public func open() {
        let waiters = state.withLock { state in
            state.isOpen = true
            let waiters = Array(state.waiters.values)
            state.waiters.removeAll()
            return waiters
        }
        for waiter in waiters { waiter.resume() }
    }
}
