#if canImport(CoreGraphics)
    import CoreGraphics
#else
    import Foundation
#endif

/// Pure geometry checks for measured layout tests and device drivers.
///
/// All frames must use one coordinate space. Invalid and empty frames never match.
///
/// ## Topics
/// - ``isUsable(_:)``
/// - ``contains(_:in:tolerance:)``
/// - ``overlaps(_:_:)``
/// - ``horizontalGap(between:and:)``
/// - ``horizontallyAligned(_:_:tolerance:)``
public enum FrameGeometry {
    /// Checks whether a frame is finite, nonempty, and has finite centers.
    /// - Parameter frame: The frame to validate.
    /// - Returns: Whether the frame can be used in layout comparisons.
    public static func isUsable(_ frame: CGRect) -> Bool {
        !frame.isEmpty && !frame.isNull && !frame.isInfinite
            && frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.midX.isFinite && frame.midY.isFinite
    }

    /// Checks containment, allowing an explicit outward margin around the container.
    /// - Parameters:
    ///   - child: The frame that should be contained.
    ///   - container: The enclosing frame.
    ///   - tolerance: The finite, nonnegative outward margin in points.
    /// - Returns: Whether valid frames satisfy containment within the margin.
    public static func contains(_ child: CGRect, in container: CGRect, tolerance: CGFloat = 0) -> Bool {
        guard isUsable(child), isUsable(container), tolerance.isFinite, tolerance >= 0 else { return false }
        let expanded = container.insetBy(dx: -tolerance, dy: -tolerance)
        return isUsable(expanded) && expanded.contains(child)
    }

    /// Checks whether two valid frames intersect with positive area.
    /// - Parameters:
    ///   - first: The first frame.
    ///   - second: The other frame in the same coordinate space.
    /// - Returns: Whether the intersection is nonempty; touching edges do not overlap.
    public static func overlaps(_ first: CGRect, _ second: CGRect) -> Bool {
        isUsable(first) && isUsable(second) && !first.intersection(second).isEmpty
    }

    /// Checks horizontal-center alignment using an exclusive tolerance.
    /// - Parameters:
    ///   - first: The first frame.
    ///   - second: The other frame.
    ///   - tolerance: The finite, positive maximum center difference in points.
    /// - Returns: Whether valid frames have horizontal centers within the tolerance.
    public static func horizontallyAligned(_ first: CGRect, _ second: CGRect, tolerance: CGFloat = 1) -> Bool {
        guard isUsable(first), isUsable(second), tolerance.isFinite, tolerance > 0 else { return false }
        return abs(first.midX - second.midX) < tolerance
    }
    /// Returns the horizontal edge separation of two valid frames, regardless of direction.
    /// - Parameters:
    ///   - first: The first frame.
    ///   - second: The other frame in the same coordinate space.
    /// - Returns: A nonnegative gap, zero for overlapping horizontal spans, or nil for invalid frames.
    public static func horizontalGap(between first: CGRect, and second: CGRect) -> CGFloat? {
        guard isUsable(first), isUsable(second) else { return nil }
        return max(0, max(first.minX, second.minX) - min(first.maxX, second.maxX))
    }

}
