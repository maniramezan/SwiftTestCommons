/// Observes an asynchronous sequence with both an event budget and a time budget.
///
/// Accepts any sendable sequence of sendable elements, such as `AsyncStream`,
/// `AsyncThrowingStream`, or a custom sequence. Cancels the consumer when time expires. Do not concurrently consume the same sequence elsewhere if every event
/// must be observed here. Zero budgets consume nothing.
///
/// A timeout or caller cancellation cancels iteration, which finishes an `AsyncStream`
/// permanently: later observations of that stream end with `.finished` and events
/// yielded afterward are dropped. Observations that end by matching or reaching the
/// limit leave the stream usable.
/// - Parameters:
///   - stream: The sequence to consume; source failures propagate unchanged.
///   - maxCount: The nonnegative event budget.
///   - timeout: The nonnegative time budget.
///   - predicate: Stops observation when true; defaults to collecting up to the limit.
/// - Returns: Collected values and the stopping reason.
/// - Throws: A source error or cancellation of the caller.
public func observeStream<Stream: AsyncSequence & Sendable>(
    _ stream: Stream, maxCount: Int, timeout: Duration,
    until predicate: @escaping @Sendable (Stream.Element) -> Bool = { _ in false }
) async throws -> StreamObservation<Stream.Element> where Stream.Element: Sendable {
    precondition(maxCount >= 0 && timeout >= .zero)
    try Task.checkCancellation()
    if maxCount == 0 {
        return .init(values: [], end: .limitReached)
    }
    if timeout == .zero {
        return .init(values: [], end: .timedOut)
    }
    let values = TestValueBox<[Stream.Element]>([])
    return try await withThrowingTaskGroup(of: StreamObservation<Stream.Element>.End.self) { group in
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
        // The group always holds both tasks here, so `next()` returns a value.
        let end = try await group.next() ?? .finished
        group.cancelAll()
        // Drain before taking the snapshot so the cancelled consumer cannot append afterward.
        while !group.isEmpty { _ = try? await group.next() }
        try Task.checkCancellation()
        return .init(values: values.get(), end: end)
    }
}
