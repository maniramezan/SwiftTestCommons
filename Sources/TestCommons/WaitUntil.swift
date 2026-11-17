/// Observes asynchronous state until it matches a predicate.
///
/// The deadline uses a monotonic clock. The operation must return promptly and
/// cooperate with cancellation; a deadline cannot interrupt arbitrary user code.
/// One observation is made even for a zero timeout. Errors propagate unchanged.
///
/// The closures run in the caller's isolation, so they can read non-sendable state
/// such as a main-actor view model. Only the observed value must be sendable.
/// - Parameters:
///   - timeout: The total observation budget, at least zero.
///   - pollInterval: The positive delay between observations.
///   - isolation: The caller's actor; leave the default.
///   - operation: Reads the state without modifying it.
///   - predicate: Returns whether an observation satisfies the condition.
/// - Returns: The first matching observation.
/// - Throws: `ObservationTimeout` with the last value, cancellation, or an operation error.
public func waitUntil<Value: Sendable>(
    timeout: Duration,
    pollInterval: Duration = .milliseconds(10),
    isolation: isolated (any Actor)? = #isolation,
    operation: () async throws -> Value,
    matching predicate: (Value) -> Bool
) async throws -> Value {
    precondition(timeout >= .zero && pollInterval > .zero)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while true {
        try Task.checkCancellation()
        let value = try await operation()
        try Task.checkCancellation()
        if predicate(value) { return value }
        let remaining = clock.now.duration(to: deadline)
        guard remaining > .zero else {
            throw ObservationTimeout(lastObservation: value)
        }
        try await clock.sleep(for: min(pollInterval, remaining))
    }
}
