import Foundation
import Testing
import TestCommons

struct SnapshotReferenceDirectoryTests {
    @Test
    func sourceReferencesTakePrecedence() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let source = directory.url.appendingPathComponent("Sources")
        let resources = directory.url.appendingPathComponent("Resources")
        let local = try makeReferences(in: source)
        _ = try makeReferences(in: resources)
        #expect(
            SnapshotReferenceDirectory.resolve(
                for: source.appendingPathComponent("ExampleTests.swift").path,
                resourceDirectories: [resources]) == local)
    }

    @Test(arguments: [true, false])
    func bundledReferencesWorkEvenWhenSourceDirectoryExists(sourceExists: Bool) throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let source = directory.url.appendingPathComponent("Sources")
        if sourceExists {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        }
        let resources = directory.url.appendingPathComponent("Resources")
        let expected = try makeReferences(in: resources)
        #expect(
            SnapshotReferenceDirectory.resolve(
                for: source.appendingPathComponent("ExampleTests.swift").path,
                resourceDirectories: [resources]) == expected)
    }

    @Test
    func onlySuppliedResourcesAreSearchedInOrder() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let first = directory.url.appendingPathComponent("First")
        let second = directory.url.appendingPathComponent("Second")
        let expected = try makeReferences(in: first, name: "References")
        _ = try makeReferences(in: second, name: "References")
        let path = directory.url.appendingPathComponent("Missing/ExampleTests.swift").path
        #expect(SnapshotReferenceDirectory.resolve(for: path) == nil)
        #expect(
            SnapshotReferenceDirectory.resolve(
                for: path, resourceDirectories: [first, second], directoryName: "References") == expected)
    }

    @Test
    func aRegularFileIsNotAReferenceDirectory() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        let references = directory.url.appendingPathComponent("__Snapshots__")
        try FileManager.default.createDirectory(at: references, withIntermediateDirectories: true)
        try Data().write(to: references.appendingPathComponent("ExampleTests"))
        #expect(
            SnapshotReferenceDirectory.resolve(
                for: directory.url.appendingPathComponent("ExampleTests.swift").path) == nil)
    }

    private func makeReferences(in root: URL, name: String = "__Snapshots__") throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("ExampleTests", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
