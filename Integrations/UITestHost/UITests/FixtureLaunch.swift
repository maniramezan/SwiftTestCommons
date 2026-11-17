import XCTest

/// Launches the fixture app on one screen, after an optional configuration step.
@MainActor
func launchFixture(_ screen: String, configure: (XCUIApplication) -> Void = { _ in }) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-FixtureScreen", screen]
    configure(app)
    app.launch()
    return app
}
