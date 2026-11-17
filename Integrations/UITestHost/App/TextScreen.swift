import SwiftUI

/// A plain text field with a placeholder and prefilled text.
struct TextScreen: View {
    @State private var name = "Ali\u{200C}رضا"
    @State private var empty = ""

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .accessibilityIdentifier("name")
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Search", text: $empty)
                .accessibilityIdentifier("search")
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
