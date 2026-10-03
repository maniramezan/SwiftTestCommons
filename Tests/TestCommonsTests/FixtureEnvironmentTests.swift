import Foundation
import Testing
import TestCommons

struct FixtureEnvironmentTests {
    @Test func environmentOverridesDoNotMutateTheirBase() {
        let base = ["KEEP": "yes", "REMOVE": "old"]
        let result = fixtureEnvironment(base: base, overrides: ["REMOVE": nil, "ADD": "new"])
        #expect(result == ["KEEP": "yes", "ADD": "new"])
        #expect(base["REMOVE"] == "old")
    }
}
