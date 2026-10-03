/// Builds an isolated environment dictionary for injection or a child process.
///
/// This never mutates the current process's environment. Nil overrides remove keys.
/// - Parameters:
///   - base: The environment to copy; defaults to an empty, isolated environment.
///   - overrides: Variables to replace or remove.
/// - Returns: The independent environment dictionary.
public func fixtureEnvironment(
    base: [String: String] = [:], overrides: [String: String?]
) -> [String: String] {
    var result = base
    for (key, value) in overrides { result[key] = value }
    return result
}
