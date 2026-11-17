import SwiftUI

/// A row of cells whose order follows the forced layout direction.
struct RowScreen: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...4, id: \.self) { day in
                Text("\(day)")
                    .frame(width: 44, height: 44)
                    .accessibilityIdentifier("day-\(day)")
            }
        }
    }
}
