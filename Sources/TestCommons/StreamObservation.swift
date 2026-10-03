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
