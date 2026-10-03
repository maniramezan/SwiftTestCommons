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

    @Test
    func directoriesAreIndependentAndCleanupIsRepeatable() throws {
        let first = try TemporaryDirectory()
        defer { try? first.remove() }
        let second = try TemporaryDirectory()
        defer { try? second.remove() }
        #expect(first.url != second.url)
        let child = first.url.appendingPathComponent("nested/payload.txt")
        try FileManager.default.createDirectory(
            at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: child)
        try first.remove()
        #expect(FileManager.default.fileExists(atPath: child.path) == false)
        #expect(FileManager.default.fileExists(atPath: first.url.path) == false)
        #expect(FileManager.default.fileExists(atPath: second.url.path))
        try first.remove()
    }

    @Test func writesCreateParentsAndStayInsideTheDirectory() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let file = try directory.write(Data("hello".utf8), named: "nested/sample.txt")
        #expect(file.lastPathComponent == "sample.txt")
        #expect(try Data(contentsOf: file) == Data("hello".utf8))
        #expect(throws: CocoaError.self) { try directory.write(Data(), named: "../outside") }
    }
}
