import Foundation
import Synchronization

/// A clock whose time advances only when a test calls ``advance(by:)`` or ``advance(to:)``.
///
/// Inject it wherever code accepts `some Clock<Duration>` to make debouncing, retries,
/// and timeouts deterministic. Sleepers resume in deadline order once time reaches
/// their deadline. Cancelling a sleeping task removes only that sleeper and throws
/// `CancellationError`; no task is created to deliver cancellation.
///
/// Start the code under test, wait for it to suspend with ``waitForSleepers(_:timeout:)``,
/// then advance. Advancing before a sleep registers does not wake it later.
///
/// ## Topics
///
/// ### Creating a clock
/// - ``init()``
/// - ``Instant``
///
/// ### Reading time
/// - ``now``
/// - ``minimumResolution``
///
/// ### Sleeping
/// - ``sleep(until:tolerance:)``
/// - ``sleeperCount``
/// - ``waitForSleepers(_:timeout:)``
///
/// ### Advancing time
/// - ``advance(by:)``
/// - ``advance(to:)``
public final class ManualClock: Clock, Sendable {
    /// A point in manual time, measured from the clock's creation.
    ///
    /// ## Topics
    /// - ``offset``
    /// - ``advanced(by:)``
    /// - ``duration(to:)``
    /// - ``<(_:_:)``
    public struct Instant: InstantProtocol, Sendable, Hashable {
        /// The elapsed manual time since the clock started at zero.
        public let offset: Duration

        /// Returns the instant a duration after this one.
        /// - Parameter duration: The amount of manual time to add; may be negative.
        /// - Returns: The resulting instant.
        public func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        /// Returns the duration from this instant to another.
        /// - Parameter other: The later or earlier instant.
        /// - Returns: A positive duration when `other` is later.
        public func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        /// Orders instants by their offsets.
        /// - Parameters:
        ///   - lhs: The first instant.
        ///   - rhs: The second instant.
        /// - Returns: Whether `lhs` occurs before `rhs`.
        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [UUID: Sleeper] = [:]
    }

    private let state = Mutex(State())

    /// Creates a clock whose current instant has a zero offset.
    public init() {}

    /// The current manual instant.
    public var now: Instant { state.withLock { $0.now } }

    /// Zero: manual time has no scheduling granularity.
    public var minimumResolution: Duration { .zero }

    /// The number of tasks currently suspended in ``sleep(until:tolerance:)``.
    public var sleeperCount: Int { state.withLock { $0.sleepers.count } }

    /// Suspends until manual time reaches `deadline`.
    ///
    /// Deadlines at or before ``now`` return immediately. The tolerance is ignored.
    /// - Parameters:
    ///   - deadline: The instant at which to resume.
    ///   - tolerance: Ignored; manual time is exact.
    /// - Throws: `CancellationError` if the task is cancelled before or while sleeping.
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let outcome: Int = state.withLock { state in
                    if Task.isCancelled { return 1 }
                    if deadline <= state.now { return 2 }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return 0
                }
                if outcome == 1 { continuation.resume(throwing: CancellationError()) }
                if outcome == 2 { continuation.resume() }
            }
        } onCancel: {
            let sleeper = state.withLock { $0.sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Advances manual time and resumes every sleeper whose deadline has been reached.
    /// - Parameter duration: A nonnegative amount of manual time.
    public func advance(by duration: Duration) {
        precondition(duration >= .zero, "ManualClock cannot move backward")
        advance(to: now.advanced(by: duration))
    }

    /// Moves manual time to `instant` and resumes sleepers due at or before it.
    ///
    /// An instant earlier than ``now`` leaves time unchanged.
    /// - Parameter instant: The target instant.
    public func advance(to instant: Instant) {
        let due: [Sleeper] = state.withLock { state in
            state.now = max(state.now, instant)
            let ready = state.sleepers.filter { $0.value.deadline <= state.now }
            for id in ready.keys { state.sleepers.removeValue(forKey: id) }
            return ready.values.sorted { $0.deadline < $1.deadline }
        }
        for sleeper in due { sleeper.continuation.resume() }
    }

    /// Waits in real time until at least `count` tasks are sleeping on this clock.
    /// - Parameters:
    ///   - count: The nonnegative number of sleepers to wait for.
    ///   - timeout: The real-time observation budget.
    /// - Throws: ``ObservationTimeout`` with the last sleeper count, or cancellation.
    public func waitForSleepers(_ count: Int, timeout: Duration = .seconds(2)) async throws {
        precondition(count >= 0)
        _ = try await waitUntil(
            timeout: timeout, pollInterval: .milliseconds(1),
            operation: { self.sleeperCount }, matching: { $0 >= count })
    }
}
