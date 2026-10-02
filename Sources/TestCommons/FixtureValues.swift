import Foundation

/// Encodes and decodes a value with the caller's serialization policy.
/// - Parameters:
///   - value: The fixture to round-trip.
///   - encoder: The encoder, including caller-specific date and key strategies.
///   - decoder: The matching decoder.
/// - Returns: The decoded value; compare it with the original in the owning test.
/// - Throws: Any encoding or decoding error.
public func jsonRoundTrip<Value: Codable>(
    _ value: Value, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()
) throws -> Value {
    try decoder.decode(Value.self, from: encoder.encode(value))
}

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
