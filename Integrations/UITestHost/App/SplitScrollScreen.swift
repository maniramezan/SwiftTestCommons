import SwiftUI

/// Two side-by-side scroll views, so a helper must find the one owning its target.
struct SplitScrollScreen: View {
    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack {
                    ForEach(0..<5) { index in
                        Text("Side \(index)").frame(height: 60)
                    }
                }
            }
            .accessibilityIdentifier("side")
            .frame(maxWidth: 120)
            ScrollView {
                LazyVStack {
                    ForEach(0..<80) { index in
                        Text("Row \(index)")
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .accessibilityIdentifier("row-\(index)")
                    }
                }
            }
            .accessibilityIdentifier("main")
        }
    }
}
