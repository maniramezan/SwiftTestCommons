/// Records sendable values in the order calls reach the actor.
///
/// Await the operation under test before inspecting values. Concurrent callers
/// have no guaranteed order until their calls are serialized by this actor.
///
/// ## Topics
///
/// ### Creating a recorder
/// - ``init()``
///
/// ### Recording and inspecting calls
/// - ``record(_:)``
/// - ``values()``
/// - ``lastValue()``
/// - ``count``
/// - ``waitForCount(_:timeout:)``
/// - ``reset()``
public actor CallRecorder<Value: Sendable> {
    private var recordedValues: [Value] = []

    /// Creates an empty recorder.
    public init() {}

    /// Appends a value to the call history.
    ///
    /// - Parameter value: The argument or event to record.
    public func record(_ value: Value) {
        recordedValues.append(value)
    }

    /// The number of recorded calls.
    public var count: Int { recordedValues.count }

    /// Clears the current history; pending count waits observe the new history.
    public func reset() { recordedValues.removeAll() }

    /// Waits for at least the requested number of calls and returns the history.
    /// - Parameters:
    ///   - count: The nonnegative minimum call count.
    ///   - timeout: The total monotonic wait budget.
    /// - Returns: A snapshot containing at least `count` calls.
    /// - Throws: Cancellation or `ObservationTimeout` containing the last history.
    public func waitForCount(_ count: Int, timeout: Duration) async throws -> [Value] {
        precondition(count >= 0)
        return try await waitUntil(
            timeout: timeout, operation: { await self.values() }, matching: { $0.count >= count })
    }

    /// Returns a snapshot of all recorded values in arrival order.
    ///
    /// Later calls to ``record(_:)`` do not change a previously returned array.
    /// - Returns: The call history, or an empty array before the first call.
    public func values() -> [Value] {
        recordedValues
    }

    /// Returns the most recently recorded value.
    ///
    /// - Returns: The last value, or `nil` when no calls have been recorded.
    public func lastValue() -> Value? {
        recordedValues.last
    }
}
