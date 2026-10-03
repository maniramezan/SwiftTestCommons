#if canImport(SwiftUI)
    #if canImport(AppKit)
        import AppKit
        /// A platform view rendered by the hosted-view helpers.
        public typealias RenderableView = NSView
    #elseif canImport(UIKit)
        import UIKit
        /// A platform view rendered by the hosted-view helpers.
        public typealias RenderableView = UIView
    #endif
#endif
