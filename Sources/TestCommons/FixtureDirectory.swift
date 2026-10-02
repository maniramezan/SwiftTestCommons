import Foundation

/// Reads fixtures beneath an explicit resource root without scanning bundles.
///
/// ## Topics
/// - ``init(root:)``
/// - ``init(bundle:subdirectory:)``
/// - ``root``
/// - ``data(named:)``
/// - ``text(named:)``
public struct FixtureDirectory: Sendable {
    /// The resource directory containing the fixtures.
    public let root: URL

    /// Creates a fixture reader for a caller-owned resource directory.
    /// - Parameter root: A file URL; the directory need not exist yet.
    public init(root: URL) { self.root = root }

    /// Creates a reader for the explicitly supplied bundle.
    /// - Parameters:
    ///   - bundle: The owning bundle, typically `Bundle.module` in a package test.
    ///   - subdirectory: An optional folder below its resource root.
    /// - Throws: A file-system error when the bundle has no resource root.
    public init(bundle: Bundle, subdirectory: String? = nil) throws {
        guard let root = bundle.resourceURL else { throw CocoaError(.fileNoSuchFile) }
        self.root = subdirectory.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
    }

    /// Loads bytes from a relative fixture path contained within the root.
    /// - Parameter name: A relative file path; traversal outside the root is rejected.
    /// - Returns: The fixture contents.
    /// - Throws: A file-system error, including missing fixtures or invalid paths.
    public func data(named name: String) throws -> Data {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let file = base.appendingPathComponent(name).standardizedFileURL.resolvingSymlinksInPath()
        guard !name.isEmpty, !name.hasPrefix("/"), file.path.hasPrefix(base.path + "/") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return try Data(contentsOf: file)
    }

    /// Loads a UTF-8 text fixture.
    /// - Parameter name: A relative fixture path beneath the root.
    /// - Returns: The decoded text, preserving whitespace.
    /// - Throws: A file-system error or a UTF-8 decoding error.
    public func text(named name: String) throws -> String {
        guard let text = String(data: try data(named: name), encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }
}
