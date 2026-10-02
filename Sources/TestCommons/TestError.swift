/// A payload-free error for exercising failure paths without a domain dependency.
///
/// ## Topics
///
/// ### Creating an error
/// - ``init()``
public struct TestError: Error, Equatable {
    /// Creates an error with no associated data. All instances compare equal.
    public init() {}
}
