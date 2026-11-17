import TestCommonsXCUI
import XCTest

final class ScrollingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testVerticalDragsRevealRowsInTheOwningContainerAndReturn() {
        let app = launchFixture("split")
        let main = app.scrollViews["main"]
        XCTAssertTrue(TestCommonsXCUI.waitForExistence(main, timeout: 10))
        let farRow = app.staticTexts["row-60"]
        XCTAssertTrue(main.scrollVerticallyUntilHittable(farRow, maxAttempts: 30, in: app), "Reveal row 60")
        // The first row now lies above the viewport, so the helper must drag downward.
        let firstRow = app.staticTexts["row-0"]
        XCTAssertTrue(app.scrollVerticallyUntilHittable(firstRow, maxAttempts: 40, in: app), "Return to row 0")
    }

    @MainActor
    func testSwipeHelpersStopOnceTheChildIsHittable() {
        let app = launchFixture("split")
        let main = app.scrollViews["main"]
        XCTAssertTrue(TestCommonsXCUI.waitForExistence(main, timeout: 10))
        XCTAssertTrue(main.scrollUpUntilHittable(app.staticTexts["row-30"], maxAttempts: 20))
        XCTAssertTrue(main.scrollDownUntilHittable(app.staticTexts["row-0"], maxAttempts: 20))
        XCTAssertFalse(main.scrollUpUntilHittable(app.staticTexts["missing"], maxAttempts: 0))
    }

    @MainActor
    func testHorizontalHelpersRevealCardsInBothDirections() {
        let app = launchFixture("carousel")
        let carousel = app.scrollViews["carousel"]
        XCTAssertTrue(TestCommonsXCUI.waitForExistence(carousel, timeout: 10))
        XCTAssertTrue(
            carousel.scrollHorizontallyUntilHittable(app.staticTexts["card-20"], maxAttempts: 30, in: app),
            "Reveal card 20")
        XCTAssertTrue(
            app.scrollHorizontallyUntilHittable(app.staticTexts["card-0"], maxAttempts: 40, in: app),
            "Return to card 0")
        XCTAssertTrue(
            carousel.scrollLeftUntilHittable(app.staticTexts["card-12"], maxAttempts: 20, velocity: .slow),
            "Swipe to card 12")
        XCTAssertTrue(carousel.scrollRightUntilHittable(app.staticTexts["card-0"], maxAttempts: 20), "Swipe to card 0")
    }
}
