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
