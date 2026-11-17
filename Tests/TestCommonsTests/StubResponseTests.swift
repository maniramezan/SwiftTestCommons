import Foundation
import Testing
import TestCommons

struct StubResponseTests {
    private struct Item: Codable, Equatable {
        let id: Int
    }

    @Test func encodedJSONSetsTheBodyAndHeader() throws {
        let response = try StubResponse.json(encoding: Item(id: 7), statusCode: 201)
        #expect(response.statusCode == 201)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(try JSONDecoder().decode(Item.self, from: response.body) == Item(id: 7))
    }

    @Test func encodingErrorsPropagate() {
        #expect(throws: EncodingError.self) { try StubResponse.json(encoding: Double.nan) }
    }
}
