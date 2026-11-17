import SwiftUI

/// Routes a launch argument to the screen a UI test exercises.
struct FixtureScreen: View {
    let name: String

    var body: some View {
        switch name {
        case "split": SplitScrollScreen()
        case "carousel": CarouselScreen()
        case "states": StatesScreen()
        case "text": TextScreen()
        case "row": RowScreen()
        default: Text("Unknown fixture screen").accessibilityIdentifier("unknown")
        }
    }
}
