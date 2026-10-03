import Foundation
import Testing

@testable import TestCommons

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct StubURLProtocolTests {
    private let url: URL

    init() throws {
        url = try #require(URL(string: "https://example.test/items?page=1"))
    }

    @Test func everyPooledProtocolRoutesItsOwnSlot() {
        #expect(StubURLProtocol.slot == -1)
        #expect(StubURLProtocol.pool.enumerated().allSatisfy { index, type in type.slot == index })
        #expect(Set(StubURLProtocol.pool.map { ObjectIdentifier($0) }).count == StubURLProtocol.pool.count)
    }

    @Test func unroutedRequestsFailInsteadOfReachingTheNetwork() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        await #expect {
            try await session.data(from: url)
        } throws: { error in
            (error as? URLError)?.code == .unsupportedURL
        }
    }

    @Test func streamedBodiesAreRecordedAsData() {
        let request = URLRequest(url: url)
        let streamed = StubURLProtocol.recordable(
            {
                var copy = request
                copy.httpBodyStream = InputStream(data: Data("streamed".utf8))
                return copy
            }())
        #expect(streamed.httpBody == Data("streamed".utf8))
        #expect(StubURLProtocol.read(InputStream(data: Data())).isEmpty)
    }
}
