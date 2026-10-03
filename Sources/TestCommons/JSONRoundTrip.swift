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
