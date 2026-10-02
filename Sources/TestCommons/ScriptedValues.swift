/// A deterministic sequence of values with an explicit exhaustion policy.
///
/// Own this value in an actor or `TestValueBox` when shared between callers.
///
/// ## Topics
/// - ``init(_:exhaustion:)``
/// - ``next()``
/// - ``remainingCount``
/// - ``Exhaustion``
public struct ScriptedValues<Value: Sendable>: Sendable {
    /// Behavior after all supplied values have been consumed.
    ///
    /// ## Topics
    /// - ``fail``
    /// - ``repeatLast``
    /// - ``fallback(_:)``
    public enum Exhaustion: Sendable {
        /// Throw `TestError` when exhausted.
        case fail
        /// Repeat the last supplied value; an empty script throws `TestError`.
        case repeatLast
        /// Return the supplied fallback after exhaustion.
        case fallback(Value)
    }
    private let values: [Value]
    private let exhaustion: Exhaustion
    private var index = 0

    /// Creates a script; an empty script is permitted.
    /// - Parameters:
    ///   - values: Values to consume in order.
    ///   - exhaustion: The behavior after the last value; defaults to failure.
    public init(_ values: [Value], exhaustion: Exhaustion = .fail) {
        self.values = values
        self.exhaustion = exhaustion
    }

    /// The number of original values that have not been consumed.
    public var remainingCount: Int { values.count - index }

    /// Consumes the next value or applies the exhaustion policy.
    /// - Returns: The next value, repeated last value, or fallback.
    /// - Throws: `TestError` when exhausted without a usable replacement.
    public mutating func next() throws -> Value {
        if index < values.count {
            defer { index += 1 }
            return values[index]
        }
        switch exhaustion {
        case .fail: throw TestError()
        case .repeatLast:
            guard let last = values.last else { throw TestError() }
            return last
        case .fallback(let value): return value
        }
    }
}
