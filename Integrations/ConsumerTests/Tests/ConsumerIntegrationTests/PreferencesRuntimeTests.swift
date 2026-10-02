import Foundation
import Testing
import TestCommons
import UserDefault

private enum FixtureMode: String, Codable { case first, second }

@UserDefaultDataStore
private struct FixturePreferences {
    @UserDefaultRecord(defaultValue: 7)
    var count: Int
    var optionalName: String?
    @UserDefaultRecord(defaultValue: FixtureMode.first, coding: .plist)
    var mode: FixtureMode
}

@Test func generatedPreferencesPersistAndRemoveInAnIsolatedSuite() throws {
    let suite = try TemporaryUserDefaults()
    defer { suite.remove() }
    var first = FixturePreferences(userDefaults: suite.defaults)
    #expect(first.count == 7)
    #expect(first.optionalName == nil)
    #expect(first.mode == .first)
    first.count = 12
    first.optionalName = "fixture"
    first.mode = .second
    let reopened = try #require(UserDefaults(suiteName: suite.suiteName))
    let second = FixturePreferences(userDefaults: reopened)
    #expect(second.count == 12)
    #expect(second.optionalName == "fixture")
    #expect(second.mode == .second)
    first.optionalName = nil
    #expect(second.optionalName == nil)
    suite.remove()
    #expect(second.count == 7)
    #expect(second.mode == .first)
}

@Test func generatedStoresDoNotSharePreferences() throws {
    let first = try TemporaryUserDefaults()
    defer { first.remove() }
    let second = try TemporaryUserDefaults()
    defer { second.remove() }
    var store = FixturePreferences(userDefaults: first.defaults)
    store.count = 99
    #expect(FixturePreferences(userDefaults: second.defaults).count == 7)
}

@Test func propertyListCodingPreservesExistingContainerData() throws {
    struct Container: Codable, Equatable { let count: Int }
    let value = Container(count: 12)
    let legacy = try PropertyListEncoder().encode(value)
    #expect(try PlistCoding().decode(Container.self, from: legacy) == value)
    let encoded = try PlistCoding().encode(value)
    #expect(try PropertyListDecoder().decode(Container.self, from: encoded) == value)
    #expect(try PlistCoding().decode(Int.self, from: PlistCoding().encode(42)) == 42)
}
