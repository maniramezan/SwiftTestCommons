import SwiftUI

/// A horizontal carousel of cards beyond the initial viewport.
struct CarouselScreen: View {
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(0..<30) { index in
                    Text("Card \(index)")
                        .frame(width: 140, height: 120)
                        .background(.quaternary)
                        .accessibilityIdentifier("card-\(index)")
                }
            }
        }
        .accessibilityIdentifier("carousel")
        .frame(height: 160)
    }
}
