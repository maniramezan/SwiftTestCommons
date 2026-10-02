import CoreGraphics

/// The direction text and content flow along the horizontal axis.
public enum ReadingDirection: Sendable, Equatable {
    case leftToRight
    case rightToLeft
}

/// Pure frame geometry for asserting that content follows its reading direction.
///
/// Everything here works on `CGRect`s, so the same check backs XCUITest, hosted-view tests, and
/// tools that read frames off a device. Frames use screen coordinates: x grows to the right.
public enum ReadingOrder {
    /// Frames whose vertical centers differ by less than this share a row.
    public static let defaultRowTolerance: CGFloat = 1

    /// Whether `a` and `b` sit on the same row.
    public static func sharesRow(
        _ a: CGRect, _ b: CGRect, tolerance: CGFloat = defaultRowTolerance
    ) -> Bool {
        abs(a.midY - b.midY) < tolerance
    }

    /// Whether `second` comes after `first` when reading in `direction`.
    ///
    /// Returns `false` for frames on different rows, because reading order across rows is not a
    /// horizontal comparison.
    public static func follows(
        _ second: CGRect, _ first: CGRect, in direction: ReadingDirection,
        rowTolerance: CGFloat = defaultRowTolerance
    ) -> Bool {
        guard sharesRow(first, second, tolerance: rowTolerance) else { return false }
        switch direction {
        case .leftToRight: return second.midX > first.midX
        case .rightToLeft: return second.midX < first.midX
        }
    }

    /// The first pair of consecutive keys, in ascending order, whose frames share a row.
    ///
    /// Used to pick two neighbouring cells of a grid (for example consecutive day numbers) without
    /// knowing where a week boundary falls.
    public static func firstAdjacentPair<Key: Comparable & Hashable>(
        in frames: [Key: CGRect], successor: (Key) -> Key,
        rowTolerance: CGFloat = defaultRowTolerance
    ) -> (first: CGRect, second: CGRect)? {
        for key in frames.keys.sorted() {
            guard let first = frames[key], let second = frames[successor(key)],
                sharesRow(first, second, tolerance: rowTolerance)
            else { continue }
            return (first, second)
        }
        return nil
    }
}
