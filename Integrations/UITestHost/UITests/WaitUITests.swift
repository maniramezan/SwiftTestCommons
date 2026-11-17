import TestCommonsXCUI
import XCTest

final class WaitUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStateWaitsObserveDelayedChanges() {
        let app = launchFixture("states")
        let submit = app.buttons["submit"]
        XCTAssertTrue(TestCommonsXCUI.waitForExistence(submit, timeout: 10, named: "Submit"))
        XCTAssertFalse(submit.isEnabled)
        app.buttons["start"].tap()
        XCTAssertTrue(TestCommonsXCUI.waitForEnabled(submit, timeout: 5, named: "Submit"))
        XCTAssertTrue(TestCommonsXCUI.waitForHittability(submit, timeout: 5, named: "Submit"))
        let status = app.staticTexts["status"]
        XCTAssertTrue(TestCommonsXCUI.waitForLabel("Status: ready", on: status, timeout: 5))
        XCTAssertTrue(TestCommonsXCUI.waitForLabelContaining("ready", on: status, timeout: 5))
        XCTAssertTrue(TestCommonsXCUI.waitForAbsence(app.staticTexts["banner"], timeout: 5, named: "Banner"))
    }

    @MainActor
    func testSelectionAndCountWaits() {
        let app = launchFixture("states")
        let second = app.buttons["Two"]
        XCTAssertTrue(TestCommonsXCUI.waitForHittability(second, timeout: 10))
        second.tap()
        XCTAssertTrue(TestCommonsXCUI.waitForSelection(second, timeout: 5, named: "Second tab"))
        let items = app.staticTexts.matching(identifier: "item")
        XCTAssertTrue(TestCommonsXCUI.waitForCount(2, of: items, timeout: 5, named: "Items"))
        app.buttons["add"].tap()
        XCTAssertTrue(TestCommonsXCUI.waitForCount(3, of: items, timeout: 5, named: "Items"))
        XCTAssertNotNil(uniqueHittableElement(in: app.buttons.matching(identifier: "add")))
    }

    @MainActor
    func testTimeoutsRecordAFailureAtTheCaller() {
        let app = launchFixture("states")
        let status = app.staticTexts["status"]
        XCTAssertTrue(TestCommonsXCUI.waitForExistence(status, timeout: 10))
        _ = XCTExpectFailure {
            TestCommonsXCUI.waitForLabel("Status: done", on: status, timeout: 0.5, named: "Status")
        } issueMatcher: { issue in
            issue.compactDescription.contains("Status did not exist with label equal to 'Status: done'")
        }
        _ = XCTExpectFailure {
            TestCommonsXCUI.waitForCount(5, of: app.staticTexts.matching(identifier: "item"), timeout: 0.5)
        } issueMatcher: { issue in
            issue.compactDescription.contains("Query did not match 5 elements")
        }
        _ = XCTExpectFailure {
            uniqueHittableElement(in: app.staticTexts.matching(identifier: "item"))
        } issueMatcher: { issue in
            issue.compactDescription.contains("Expected one hittable element, found 2")
        }
        attachDiagnostics(of: app, to: self, named: "States", lifetime: .deleteOnSuccess)
    }
}
