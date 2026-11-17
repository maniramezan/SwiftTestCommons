import SwiftUI

/// Controls whose state changes after a delay, for the wait helpers.
struct StatesScreen: View {
    @State private var ready = false
    @State private var bannerVisible = true
    @State private var items = 2
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 16) {
            Button("Start") {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    ready = true
                    bannerVisible = false
                }
            }
            .accessibilityIdentifier("start")
            Button("Submit") {}
                .disabled(!ready)
                .accessibilityIdentifier("submit")
            Text(ready ? "Status: ready" : "Status: idle")
                .accessibilityIdentifier("status")
            if bannerVisible {
                Text("Loading banner").accessibilityIdentifier("banner")
            }
            Picker("Tab", selection: $tab) {
                Text("One").tag(0)
                Text("Two").tag(1)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tabs")
            Button("Add item") { items += 1 }
                .accessibilityIdentifier("add")
            VStack {
                ForEach(0..<items, id: \.self) { index in
                    Text("Item \(index)").accessibilityIdentifier("item")
                }
            }
        }
        .padding()
    }
}
