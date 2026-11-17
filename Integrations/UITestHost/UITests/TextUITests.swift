import TestCommonsXCUI
import XCTest

final class TextUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testReplacingTextClearsJoinedScriptsAndPlaceholders() {
        let app = launchFixture("text")
        XCTAssertTrue(replaceText(in: app.textFields["name"], with: "Mani", timeout: 10, named: "Name"))
        XCTAssertTrue(replaceText(in: app.textFields["search"], with: "abc", timeout: 10, named: "Search"))
        XCTAssertTrue(replaceText(in: app.textFields["search"], with: "", timeout: 10, named: "Search"))
    }
}
