/// A condition did not match before its deadline.
///
/// ## Topics
/// - ``lastObservation``
public struct ObservationTimeout<Value: Sendable>: Error {
    /// The most recent value observed before the deadline.
    public let lastObservation: Value
}
