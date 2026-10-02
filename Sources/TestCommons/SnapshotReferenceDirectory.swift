import Foundation

/// Finds snapshot references beside a source file or in caller-supplied resources.
///
/// Supply the owning test bundle's resource URL explicitly. Searching all bundles
/// can select another target's references when test filenames collide.
///
/// ## Topics
///
/// ### Resolving references
/// - ``resolve(for:resourceDirectories:directoryName:)``
public enum SnapshotReferenceDirectory {
    /// Returns `nil` when no reference directory exists, leaving recording policy to the caller.
    ///
    /// For a source file named `ExampleTests.swift`, candidates end in
    /// `__Snapshots__/ExampleTests/`. The source file's parent is searched first,
    /// followed by `resourceDirectories` in order. Only existing directories match;
    /// regular files are skipped. This method does not create directories.
    ///
    /// - Parameters:
    ///   - filePath: The source file path, typically `#filePath` from the calling test.
    ///   - resourceDirectories: Resource roots from the owning test bundle. Defaults to none.
    ///   - directoryName: The reference folder name under each root. Defaults to `__Snapshots__`.
    /// - Returns: The first matching directory URL, or `nil` for the snapshot library's default.
    public static func resolve(
        for filePath: String,
        resourceDirectories: [URL] = [],
        directoryName: String = "__Snapshots__"
    ) -> URL? {
        let source = URL(fileURLWithPath: filePath)
        let testName = source.deletingPathExtension().lastPathComponent
        let roots = [source.deletingLastPathComponent()] + resourceDirectories
        for root in roots {
            let candidate = root.appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent(testName, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                isDirectory.boolValue
            {
                return candidate
            }
        }
        return nil
    }
}
