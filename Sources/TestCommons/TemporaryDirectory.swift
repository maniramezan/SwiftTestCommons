import Foundation

/// An independently owned scratch directory. Call `remove()` in a `defer` block.
///
/// Explicit cleanup lets callers observe errors and choose their own lifetime,
/// including keeping the directory alive across asynchronous operations.
///
/// ## Topics
///
/// ### Managing a directory
/// - ``init()``
/// - ``url``
/// - ``remove()``
/// - ``write(_:named:)``
public struct TemporaryDirectory: Sendable {
    /// The unique directory URL, created beneath the system temporary directory.
    public let url: URL

    /// Creates an empty directory with a UUID name.
    ///
    /// Copies of this value refer to the same directory; they do not create
    /// independent resources. Cleanup is explicit, not tied to deinitialization.
    /// - Throws: A file-system error if the directory cannot be created.
    public init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    /// Writes a fixture file beneath this scratch directory, creating parent folders.
    /// - Parameters:
    ///   - data: The bytes to write atomically.
    ///   - name: A relative filename; escaping the scratch directory is rejected.
    /// - Returns: The new file URL.
    /// - Throws: A file-system error or an invalid relative-path error.
    public func write(_ data: Data, named name: String) throws -> URL {
        let base = url.standardizedFileURL.resolvingSymlinksInPath()
        let file = base.appendingPathComponent(name).standardizedFileURL.resolvingSymlinksInPath()
        guard !name.isEmpty, !name.hasPrefix("/"), file.path.hasPrefix(base.path + "/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }

    /// Removes the directory and its contents. Already-removed directories are harmless.
    ///
    /// Finish operations using ``url`` before calling this method. The directory
    /// is not recreated afterward, and concurrent removal is not coordinated.
    /// - Throws: A file-system error other than a missing-directory error.
    public func remove() throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }
}
