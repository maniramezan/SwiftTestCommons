/// A deterministic sequence of values with an explicit exhaustion policy.
///
/// Own this value in an actor or `TestValueBox` when shared between callers.
///
/// ## Topics
/// - ``init(_:exhaustion:)``
/// - ``next()``
/// - ``remainingCount``
/// - ``Exhaustion``
/// - ``Exhausted``
public struct ScriptedValues<Value: Sendable>: Sendable {
    /// Behavior after all supplied values have been consumed.
    ///
    /// ## Topics
    /// - ``fail``
    /// - ``repeatLast``
    /// - ``fallback(_:)``
    public enum Exhaustion: Sendable {
        /// Throw ``ScriptedValues/Exhausted`` when exhausted.
        case fail
        /// Repeat the last supplied value; an empty script throws ``ScriptedValues/Exhausted``.
        case repeatLast
        /// Return the supplied fallback after exhaustion.
        case fallback(Value)
    }

    /// Thrown when a script runs out of values and its policy supplies no replacement.
    ///
    /// Distinct from errors your test scripts or expects, such as `TestError`, so an
    /// unexpected extra call cannot satisfy an expected failure.
    ///
    /// ## Topics
    /// - ``consumedCount``
    public struct Exhausted: Error, Equatable {
        /// The number of values the script supplied before running out.
        public let consumedCount: Int
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
    /// - Throws: ``Exhausted`` when exhausted without a usable replacement.
    public mutating func next() throws -> Value {
        if index < values.count {
            defer { index += 1 }
            return values[index]
        }
        switch exhaustion {
        case .fail: throw Exhausted(consumedCount: values.count)
        case .repeatLast:
            guard let last = values.last else {
                throw Exhausted(consumedCount: 0)
            }
            return last
        case .fallback(let value): return value
        }
    }
}
