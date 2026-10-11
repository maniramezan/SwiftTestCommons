import Foundation

/// Resolves a relative path beneath `root`, or returns nil when it is empty, absolute,
/// or escapes the root through `..` components or symbolic links.
func containedFileURL(_ name: String, in root: URL) -> URL? {
    let base = root.standardizedFileURL.resolvingSymlinksInPath()
    let file = base.appendingPathComponent(name).standardizedFileURL.resolvingSymlinksInPath()
    guard !name.isEmpty, !name.hasPrefix("/"), file.path.hasPrefix(base.path + "/") else {
        return nil
    }
    return file
}
