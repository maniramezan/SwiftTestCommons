import Foundation
import Testing
import TestCommons

struct FixtureDirectoryTests {
    @Test func fixturesAreReadBelowTheRootAndDecodeUTF8() throws {
        let directory = try TemporaryDirectory()
        defer { try? directory.remove() }
        _ = try directory.write(Data("hello".utf8), named: "nested/sample.txt")
        let fixtures = FixtureDirectory(root: directory.url)
        #expect(try fixtures.text(named: "nested/sample.txt") == "hello")
        #expect(throws: CocoaError.self) { try fixtures.data(named: "../outside") }
        #expect(throws: CocoaError.self) { try fixtures.data(named: "missing") }
        #expect(throws: CocoaError.self) { try fixtures.data(named: "") }
        #expect(throws: CocoaError.self) { try fixtures.data(named: "/etc/hosts") }
        _ = try directory.write(Data([0xFF, 0xFE, 0xFD]), named: "binary.bin")
        #expect(throws: CocoaError.self) { try fixtures.text(named: "binary.bin") }
        #expect(try fixtures.data(named: "binary.bin") == Data([0xFF, 0xFE, 0xFD]))
    }

    @Test func bundleFixturesResolveBelowTheResourceRoot() throws {
        let resources = try #require(Bundle.main.resourceURL)
        #expect(try FixtureDirectory(bundle: .main).root == resources)
        let nested = try FixtureDirectory(bundle: .main, subdirectory: "Fixtures")
        #expect(nested.root == resources.appendingPathComponent("Fixtures", isDirectory: true))
    }
}
