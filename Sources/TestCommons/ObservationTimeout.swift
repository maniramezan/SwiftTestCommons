/// A condition did not match before its deadline.
///
/// ## Topics
/// - ``lastObservation``
/// - ``description``
public struct ObservationTimeout<Value: Sendable>: Error, CustomStringConvertible {
    /// The most recent value observed before the deadline.
    public let lastObservation: Value

    /// A failure message that includes the last observed value.
    public var description: String {
        "Condition did not match before the deadline; last observation: \(lastObservation)"
    }
}
