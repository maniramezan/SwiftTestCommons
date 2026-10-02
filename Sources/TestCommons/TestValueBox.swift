import Synchronization

/// Synchronous, thread-safe storage for dependency spies and callback state.
///
/// Values must be sendable so reading a reference cannot bypass its isolation.
///
/// ## Topics
///
/// ### Creating a box
/// - ``init(_:)``
///
/// ### Accessing state
/// - ``get()``
/// - ``set(_:)``
/// - ``withValue(_:)``
public final class TestValueBox<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    /// Creates a box containing the initial value.
    ///
    /// - Parameter value: The initial state to share between callbacks.
    public init(_ value: Value) {
        storage = Mutex(value)
    }

    /// Reads the current value under the lock.
    ///
    /// A separate read followed by ``set(_:)`` is not an atomic update.
    /// Use ``withValue(_:)`` for read-modify-write operations.
    /// - Returns: The value at the moment the lock is acquired.
    public func get() -> Value {
        storage.withLock { $0 }
    }

    /// Replaces the stored value under the lock.
    ///
    /// - Parameter value: The replacement state.
    public func set(_ value: Value) {
        storage.withLock { $0 = value }
    }

    /// Reads and modifies the value in one critical section.
    ///
    /// Do not call this box's methods from `body`; the lock is not recursive.
    /// The closure runs synchronously and must not suspend. If it throws, the
    /// lock is released and any mutations made before the error remain.
    ///
    /// - Parameter body: A synchronous operation with exclusive access to the value.
    /// - Returns: The result returned by `body`.
    /// - Throws: Any error thrown by `body`.
    @discardableResult
    public func withValue<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        try storage.withLock { try body(&$0) }
    }
}
