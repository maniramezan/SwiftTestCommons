import Foundation
import Testing
import TestCommons

struct TemporaryDirectoryTests {
    @Test func prefixLabelsTheDirectory() throws {
        let directory = try TemporaryDirectory(prefix: "LoginTests")
        defer { try? directory.remove() }
        #expect(directory.url.lastPathComponent.hasPrefix("LoginTests-"))
        #expect(FileManager.default.fileExists(atPath: directory.url.path))
    }

    @Test(arguments: ["", "a/b", ".", ".."])
    func unusablePrefixesAreRejected(prefix: String) {
        #expect(throws: CocoaError.self) { try TemporaryDirectory(prefix: prefix) }
    }
}
