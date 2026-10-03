/// Values collected while observing a stream, including its stopping reason.
///
/// ## Topics
/// - ``values``
/// - ``end``
/// - ``End``
public struct StreamObservation<Element: Sendable>: Sendable {
    /// Why observation stopped.
    ///
    /// ## Topics
    /// - ``matched``
    /// - ``limitReached``
    /// - ``finished``
    /// - ``timedOut``
    public enum End: Sendable, Equatable {
        /// The supplied predicate accepted an event.
        case matched
        /// The event budget was consumed.
        case limitReached
        /// The source finished before matching or reaching the limit.
        case finished
        /// The monotonic deadline expired.
        case timedOut
    }
    /// Events in delivery order, including a matching event when present.
    public let values: [Element]
    /// The reason observation stopped.
    public let end: End
}

/// Observes a stream with both an event budget and a time budget.
///
/// Cancels the consumer when time expires. Do not concurrently consume the same
/// stream elsewhere if every event must be observed here. Zero budgets consume nothing.
///
/// A timeout or caller cancellation cancels iteration, which finishes an `AsyncStream`
/// permanently: later observations of that stream end with `.finished` and events
/// yielded afterward are dropped. Observations that end by matching or reaching the
/// limit leave the stream usable.
/// - Parameters:
///   - stream: The stream to consume.
///   - maxCount: The nonnegative event budget.
///   - timeout: The nonnegative time budget.
///   - predicate: Stops observation when true; defaults to collecting up to the limit.
/// - Returns: Collected values and the stopping reason.
/// - Throws: Cancellation of the caller.
public func observeStream<Element: Sendable>(
    _ stream: AsyncStream<Element>, maxCount: Int, timeout: Duration,
    until predicate: @escaping @Sendable (Element) -> Bool = { _ in false }
) async throws -> StreamObservation<Element> {
    try await observe(stream, maxCount: maxCount, timeout: timeout, until: predicate)
}

/// Observes a throwing stream with an event budget and a monotonic deadline.
///
/// As with the non-throwing overload, a timeout or caller cancellation finishes the
/// stream; only observations that match or reach the limit leave it usable.
/// - Parameters:
///   - stream: The stream to consume; source failures propagate unchanged.
///   - maxCount: The nonnegative event budget.
///   - timeout: The nonnegative time budget.
///   - predicate: Stops observation when true; defaults to collecting up to the limit.
/// - Returns: Collected values and the stopping reason.
/// - Throws: A source error or cancellation of the caller.
public func observeStream<Element: Sendable>(
    _ stream: AsyncThrowingStream<Element, any Error>, maxCount: Int, timeout: Duration,
    until predicate: @escaping @Sendable (Element) -> Bool = { _ in false }
) async throws -> StreamObservation<Element> {
    try await observe(stream, maxCount: maxCount, timeout: timeout, until: predicate)
}

private func observe<S: AsyncSequence & Sendable>(
    _ stream: S, maxCount: Int, timeout: Duration,
    until predicate: @escaping @Sendable (S.Element) -> Bool
) async throws -> StreamObservation<S.Element> where S.Element: Sendable {
    precondition(maxCount >= 0 && timeout >= .zero)
    try Task.checkCancellation()
    if maxCount == 0 {
        return .init(values: [], end: .limitReached)
    }
    if timeout == .zero {
        return .init(values: [], end: .timedOut)
    }
    let values = TestValueBox<[S.Element]>([])
    return try await withThrowingTaskGroup(of: StreamObservation<S.Element>.End.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            while let value = try await iterator.next() {
                try Task.checkCancellation()
                values.withValue { $0.append(value) }
                if predicate(value) {
                    return .matched
                }
                if values.get().count >= maxCount {
                    return .limitReached
                }
            }
            try Task.checkCancellation()
            return .finished
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            return .timedOut
        }
        defer { group.cancelAll() }
        let end = try await group.next()!
        group.cancelAll()
        // Drain before taking the snapshot so the cancelled consumer cannot append afterward.
        while !group.isEmpty { _ = try? await group.next() }
        try Task.checkCancellation()
        return .init(values: values.get(), end: end)
    }
}
