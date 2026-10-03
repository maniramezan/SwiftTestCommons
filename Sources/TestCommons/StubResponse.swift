import Foundation

/// A canned HTTP response returned by a ``StubbedURLSession``.
///
/// ## Topics
///
/// ### Creating responses
/// - ``init(statusCode:headers:body:)``
/// - ``json(_:statusCode:)``
/// - ``text(_:statusCode:)``
///
/// ### Response contents
/// - ``statusCode``
/// - ``headers``
/// - ``body``
public struct StubResponse: Sendable, Equatable {
    /// The HTTP status code.
    public var statusCode: Int
    /// The response header fields.
    public var headers: [String: String]
    /// The response body bytes.
    public var body: Data

    /// Creates a response.
    /// - Parameters:
    ///   - statusCode: The HTTP status code; defaults to 200.
    ///   - headers: The response header fields.
    ///   - body: The response body bytes.
    public init(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// Creates a JSON response with a `Content-Type: application/json` header.
    /// - Parameters:
    ///   - json: The UTF-8 JSON text.
    ///   - statusCode: The HTTP status code; defaults to 200.
    /// - Returns: The response.
    public static func json(_ json: String, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, headers: ["Content-Type": "application/json"], body: Data(json.utf8))
    }

    /// Creates a plain-text response with a `Content-Type: text/plain` header.
    /// - Parameters:
    ///   - text: The UTF-8 body text.
    ///   - statusCode: The HTTP status code; defaults to 200.
    /// - Returns: The response.
    public static func text(_ text: String, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, headers: ["Content-Type": "text/plain"], body: Data(text.utf8))
    }
}
