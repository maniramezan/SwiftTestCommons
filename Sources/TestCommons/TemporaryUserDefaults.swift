import Foundation

/// A unique preferences suite for one test. Call `remove()` in a `defer` block.
///
/// Pass `defaults` to the code under test instead of mutating `UserDefaults.standard`.
///
/// ## Topics
///
/// ### Managing a suite
/// - ``init()``
/// - ``suiteName``
/// - ``defaults``
/// - ``remove()``
///
/// ### Handling initialization failures
/// - ``CreationError``
public struct TemporaryUserDefaults {
    /// The unique suite identifier, usable to reopen these preferences in another instance.
    public let suiteName: String
    /// The preferences instance to inject into the code under test.
    ///
    /// This instance uses the normal `UserDefaults` search domains. Isolation
    /// applies to writes in its persistent suite, not to global or registered defaults.
    public let defaults: UserDefaults

    /// An error raised when Foundation cannot create an isolated preferences suite.
    ///
    /// ## Topics
    ///
    /// ### Suite errors
    /// - ``unavailableSuite(_:)``
    public enum CreationError: Error {
        /// The suite could not be initialized with the supplied identifier.
        ///
        /// The associated string is the generated suite name.
        case unavailableSuite(String)
    }

    /// Creates a uniquely named suite and clears any persistent values for that name.
    ///
    /// Copies share the suite and preferences instance. Call ``remove()``
    /// explicitly when finished; deinitialization does not clear the suite.
    /// - Throws: ``CreationError/unavailableSuite(_:)`` if the suite cannot be initialized.
    public init() throws {
        suiteName = "TestCommons.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CreationError.unavailableSuite(suiteName)
        }
        self.defaults = defaults
        remove()
    }

    /// Removes persisted values from this suite only. Safe to call repeatedly.
    ///
    /// Other suites and `UserDefaults.standard` are unaffected. Registered defaults
    /// are not removed, and later writes to ``defaults`` can populate the suite again.
    public func remove() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
