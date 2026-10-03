import Foundation
import Testing
import TestCommons

struct ScriptedValuesTests {
    @Test func scriptsHaveExplicitExhaustion() throws {
        var failing = ScriptedValues([1])
        #expect(try failing.next() == 1)
        #expect(throws: TestError()) { try failing.next() }
        var repeating = ScriptedValues([1, 2], exhaustion: .repeatLast)
        #expect(repeating.remainingCount == 2)
        #expect(try repeating.next() == 1)
        #expect(try repeating.next() == 2)
        #expect(repeating.remainingCount == 0)
        #expect(try repeating.next() == 2)
        #expect(repeating.remainingCount == 0)
        var emptyRepeating = ScriptedValues<Int>([], exhaustion: .repeatLast)
        #expect(throws: TestError()) { try emptyRepeating.next() }
        var fallback = ScriptedValues<Int>([], exhaustion: .fallback(3))
        #expect(try fallback.next() == 3)
    }
}
