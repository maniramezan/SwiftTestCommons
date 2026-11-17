#if HOSTING_APPKIT || HOSTING_UIKIT
    import SwiftUI

    /// Platform appearance overrides applied to a ``HostedView``'s window hierarchy.
    ///
    /// These set platform traits, so they reach platform-backed controls such as lists and
    /// text fields as well as SwiftUI's environment. `nil` keeps the system value. On macOS,
    /// AppKit has no Dynamic Type trait; apply `.dynamicTypeSize(_:)` to the content there.
    ///
    /// ## Topics
    /// - ``init(colorScheme:layoutDirection:dynamicTypeSize:)``
    /// - ``colorScheme``
    /// - ``layoutDirection``
    /// - ``dynamicTypeSize``
    public struct HostedAppearance: Sendable, Equatable {
        /// The light or dark appearance, or nil for the system appearance.
        public var colorScheme: ColorScheme?
        /// The horizontal layout direction, or nil for the system direction.
        public var layoutDirection: LayoutDirection?
        /// The text size category on UIKit platforms, or nil for the system size.
        public var dynamicTypeSize: DynamicTypeSize?

        /// Creates appearance overrides; omitted values keep the system setting.
        /// - Parameters:
        ///   - colorScheme: The light or dark appearance.
        ///   - layoutDirection: The horizontal layout direction.
        ///   - dynamicTypeSize: The text size category, applied on UIKit platforms.
        public init(
            colorScheme: ColorScheme? = nil, layoutDirection: LayoutDirection? = nil,
            dynamicTypeSize: DynamicTypeSize? = nil
        ) {
            self.colorScheme = colorScheme
            self.layoutDirection = layoutDirection
            self.dynamicTypeSize = dynamicTypeSize
        }
    }
#endif
