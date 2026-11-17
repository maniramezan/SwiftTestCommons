import TestCommons
import TestCommonsXCUI
import XCTest

final class LaunchConfigurationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func dayFrames(in app: XCUIApplication) -> [CGRect] {
        (1...4).map { day in
            let cell = app.staticTexts["day-\(day)"]
            XCTAssertTrue(TestCommonsXCUI.waitForExistence(cell, timeout: 10, named: "Day \(day)"))
            return cell.frame
        }
    }

    @MainActor
    func testForcedRightToLeftLayoutMirrorsTheRow() {
        let app = launchFixture("row") { app in
            configureLayoutDirection(of: app, .rightToLeft)
        }
        XCTAssertReadingOrder(dayFrames(in: app), direction: .rightToLeft, "Forced RTL")
    }

    @MainActor
    func testLocaleAndContentSizeArgumentsLaunchTheApp() {
        let app = launchFixture("row") { app in
            configureLocale(of: app, language: "en", locale: "en_US")
            configureLayoutDirection(of: app, .leftToRight)
            configureContentSizeCategory(of: app, "UICTContentSizeCategoryAccessibilityXL")
        }
        XCTAssertReadingOrder(dayFrames(in: app), direction: .leftToRight, "Forced LTR")
    }
}
