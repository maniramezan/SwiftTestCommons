import Foundation
import Testing
import TestCommons

struct JSONRoundTripTests {
    @Test func roundTripUsesCallerDatePolicy() throws {
        struct Fixture: Codable, Equatable { let date: Date }
        let fixture = Fixture(date: Date(timeIntervalSince1970: 1.125))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        #expect(try jsonRoundTrip(fixture, encoder: encoder, decoder: decoder) == fixture)
    }
}
