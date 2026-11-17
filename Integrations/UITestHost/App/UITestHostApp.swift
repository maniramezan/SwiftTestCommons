import SwiftUI

/// Hosts one fixture screen per launch, chosen with `-FixtureScreen <name>`.
@main
struct UITestHostApp: App {
    var body: some Scene {
        WindowGroup {
            FixtureScreen(name: UserDefaults.standard.string(forKey: "FixtureScreen") ?? "")
        }
    }
}
