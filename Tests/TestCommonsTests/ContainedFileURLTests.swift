import Foundation
import Testing

@testable import TestCommons

struct ContainedFileURLTests {
    @Test(arguments: ["", "/etc/hosts", "..", "../sibling", "nested/../../escape"])
    func pathsOutsideTheRootAreRejected(name: String) throws {
        let root = try TemporaryDirectory()
        defer { try? root.remove() }
        #expect(containedFileURL(name, in: root.url) == nil)
    }

    @Test func nestedRelativePathsResolveBeneathTheRoot() throws {
        let root = try TemporaryDirectory()
        defer { try? root.remove() }
        let file = try #require(containedFileURL("nested/./fixture.json", in: root.url))
        #expect(file.lastPathComponent == "fixture.json")
        #expect(file.deletingLastPathComponent().lastPathComponent == "nested")
    }
}
