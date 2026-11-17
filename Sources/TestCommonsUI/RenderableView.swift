#if HOSTING_APPKIT
    import AppKit
    /// A platform view rendered by the hosted-view helpers.
    public typealias RenderableView = NSView
#elseif HOSTING_UIKIT
    import UIKit
    /// A platform view rendered by the hosted-view helpers.
    public typealias RenderableView = UIView
#endif
