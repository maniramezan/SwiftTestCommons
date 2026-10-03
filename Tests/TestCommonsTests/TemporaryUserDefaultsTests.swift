import Foundation
import Testing
import TestCommons

struct TemporaryUserDefaultsTests {
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
