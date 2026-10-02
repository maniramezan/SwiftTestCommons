import CoreGraphics

/// The direction text and content flow along the horizontal axis.
///
/// ## Topics
///
/// ### Horizontal directions
/// - ``leftToRight``
/// - ``rightToLeft``
public enum ReadingDirection: Sendable, Equatable {
    /// Content advances toward increasing horizontal coordinates.
    case leftToRight
    /// Content advances toward decreasing horizontal coordinates.
    case rightToLeft
}

/// Pure frame geometry for asserting that content follows its reading direction.
///
/// Everything here works on `CGRect`s, so the same check backs XCUITest, hosted-view tests, and
/// tools that read frames off a device. Frames use screen coordinates: x grows to the right.
///
/// ## Topics
///
/// ### Comparing frames
/// - ``sharesRow(_:_:tolerance:)``
/// - ``follows(_:_:in:rowTolerance:)``
/// - ``defaultRowTolerance``
///
/// ### Selecting candidates
/// - ``firstAdjacentPair(in:successor:rowTolerance:)``
public enum ReadingOrder {
    /// Frames whose vertical centers differ by less than this share a row.
    public static let defaultRowTolerance: CGFloat = 1

    /// Whether `a` and `b` sit on the same row.
    ///
    /// Frames must be finite and nonempty, and tolerance must be finite and positive.
    /// The tolerance boundary is exclusive.
    ///
    /// - Parameters:
    ///   - a: A frame in the same screen-coordinate space as `b`.
    ///   - b: The other frame to compare.
    ///   - tolerance: The exclusive maximum distance between vertical centers, in points.
    /// - Returns: Whether both frames are usable and their vertical centers differ by less than `tolerance`.
    public static func sharesRow(
        _ a: CGRect, _ b: CGRect, tolerance: CGFloat = defaultRowTolerance
    ) -> Bool {
        guard tolerance.isFinite, tolerance > 0, isUsable(a), isUsable(b) else { return false }
        return abs(a.midY - b.midY) < tolerance
    }

    /// Whether `second` comes after `first` when reading in `direction`.
    ///
    /// Returns `false` for frames on different rows, because reading order across rows is not a
    /// horizontal comparison.
    /// Equal horizontal centers never follow each other. Overlapping frames can
    /// follow each other because this checks centers rather than edge separation.
    ///
    /// - Parameters:
    ///   - second: The frame expected to occur later in the reading direction.
    ///   - first: The frame expected to occur earlier, in the same coordinate space.
    ///   - direction: The horizontal direction to check.
    ///   - rowTolerance: The exclusive vertical-center tolerance, in points.
    /// - Returns: Whether the frames share a row and `second` advances from `first` in `direction`.
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
    /// Successors that do not advance the key are skipped.
    /// Missing successors, invalid frames, and row breaks are also skipped.
    /// This chooses a candidate pair; it does not validate its horizontal order.
    ///
    /// - Parameters:
    ///   - frames: Frames indexed by sortable keys, all in the same coordinate space.
    ///   - successor: Computes the next logical key. It must handle every supplied key,
    ///     including the terminal key, without overflow or other failures. Returning
    ///     the same key for a terminal value safely skips it.
    ///   - rowTolerance: The exclusive vertical-center tolerance, in points.
    /// - Returns: The first matching pair of frames in key order, or `nil` if none matches.
    public static func firstAdjacentPair<Key: Comparable & Hashable>(
        in frames: [Key: CGRect], successor: (Key) -> Key,
        rowTolerance: CGFloat = defaultRowTolerance
    ) -> (first: CGRect, second: CGRect)? {
        for key in frames.keys.sorted() {
            let next = successor(key)
            guard next > key, let first = frames[key], let second = frames[next],
                sharesRow(first, second, tolerance: rowTolerance)
            else { continue }
            return (first, second)
        }
        return nil
    }

    private static func isUsable(_ frame: CGRect) -> Bool {
        !frame.isEmpty && !frame.isNull && !frame.isInfinite
            && frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.size.width.isFinite && frame.size.height.isFinite
            && frame.midX.isFinite && frame.midY.isFinite
    }
}
