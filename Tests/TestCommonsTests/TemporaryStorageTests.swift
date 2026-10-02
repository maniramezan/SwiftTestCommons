import Foundation
import Testing
import TestCommons

struct TemporaryStorageTests {
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

    @Test
    func preferencesSuitesAreIndependentAndPersistAcrossInstances() throws {
        let first = try TemporaryUserDefaults()
        defer { first.remove() }
        let second = try TemporaryUserDefaults()
        defer { second.remove() }
        #expect(first.suiteName != second.suiteName)
        #expect(first.defaults.object(forKey: "setting") == nil)
        first.defaults.set("value", forKey: "setting")
        let reopened = try #require(UserDefaults(suiteName: first.suiteName))
        #expect(reopened.string(forKey: "setting") == "value")
        #expect(second.defaults.object(forKey: "setting") == nil)
        second.defaults.set("other", forKey: "setting")
        first.remove()
        first.remove()
        #expect(reopened.object(forKey: "setting") == nil)
        #expect(second.defaults.string(forKey: "setting") == "other")
    }
}
