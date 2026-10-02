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
