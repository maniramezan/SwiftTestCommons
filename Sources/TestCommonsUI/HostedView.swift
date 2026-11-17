#if HOSTING_APPKIT || HOSTING_UIKIT
    import Foundation
    import SwiftUI
    #if HOSTING_APPKIT
        import AppKit
    #else
        import UIKit
    #endif

    /// Owns a real platform hierarchy for rendering a SwiftUI view in tests.
    ///
    /// Call `close()` when finished, or use ``withHostedView(_:size:visible:scale:appearance:_:)``
    /// to close automatically. Tests pumping the main run loop should be serialized.
    ///
    /// On iOS, SwiftUI builds a hosted hierarchy only in a test target with a host
    /// application. In a hostless package test bundle, renders return nil; use
    /// ``ViewRendering/pngData(rendering:size:scale:)`` there instead.
    ///
    /// ## Topics
    ///
    /// ### Hosting a view
    /// - ``init(_:size:visible:scale:appearance:)``
    /// - ``init(_:fittingWidth:visible:scale:appearance:)``
    /// - ``withHostedView(_:size:visible:scale:appearance:_:)``
    /// - ``HostedAppearance``
    /// - ``hosting``
    /// - ``window``
    /// - ``close()``
    ///
    /// ### Rendering
    /// - ``renderPNG()``
    /// - ``waitForStableRender(timeout:minimumFrames:requiredStableFrames:pollInterval:)``
    /// - ``rendersDifferently(from:)``
    @MainActor
    public final class HostedView<Content: View> {
        #if HOSTING_APPKIT
            /// The hosted view or controller; retain its window while observing it.
            public let hosting: NSHostingView<Content>
            /// The owned platform window; use `close()` for coordinated cleanup.
            public let window: NSWindow
        #else
            /// The hosted view or controller; retain its window while observing it.
            public let hosting: UIHostingController<Content>
            /// The owned platform window; use `close()` for coordinated cleanup.
            public let window: UIWindow
        #endif
        private let scale: CGFloat?
        private var closed = false

        /// Creates a window hosting the view and performs its initial layout.
        /// - Parameters:
        ///   - content: The view to render, including any required environment values.
        ///   - size: A finite, positive render size in points.
        ///   - visible: Whether to show the window; lazy content may require visibility.
        ///   - scale: The finite, positive pixels-per-point factor for renders, or nil for
        ///     the display's scale. Pass a fixed value to compare renders across devices.
        ///   - appearance: Platform appearance overrides, such as dark mode or right-to-left layout.
        public init(
            _ content: Content, size: CGSize, visible: Bool = true, scale: CGFloat? = nil,
            appearance: HostedAppearance = HostedAppearance()
        ) {
            precondition(size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
            precondition(scale.map { $0.isFinite && $0 > 0 } ?? true)
            self.scale = scale
            #if HOSTING_APPKIT
                hosting = NSHostingView(rootView: content)
                hosting.frame = CGRect(origin: .zero, size: size)
                Self.apply(appearance, to: hosting)
                window = NSWindow(
                    contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = hosting
                if visible {
                    window.orderFront(nil)
                }
                window.layoutIfNeeded()
                hosting.layoutSubtreeIfNeeded()
            #else
                hosting = UIHostingController(rootView: content)
                hosting.view.frame = CGRect(origin: .zero, size: size)
                Self.apply(appearance, to: hosting)
                // In a scene-based host app, a window without a scene is never displayed.
                if let scene = UIApplication.shared.connectedScenes.lazy.compactMap({ $0 as? UIWindowScene }).first {
                    window = UIWindow(windowScene: scene)
                    window.frame = hosting.view.frame
                } else {
                    window = UIWindow(frame: hosting.view.frame)
                }
                window.rootViewController = hosting
                window.isHidden = !visible
                hosting.view.setNeedsLayout()
                hosting.view.layoutIfNeeded()
            #endif
        }

        /// Creates a window sized to the content's ideal height at a fixed width.
        ///
        /// Measures with a platform hosting controller, so platform-backed controls size as
        /// they do in an app.
        /// - Parameters:
        ///   - content: The view to render, including any required environment values.
        ///   - width: A finite, positive width in points.
        ///   - visible: Whether to show the window; lazy content may require visibility.
        ///   - scale: The finite, positive pixels-per-point factor for renders, or nil for
        ///     the display's scale.
        ///   - appearance: Platform appearance overrides applied while measuring and rendering.
        /// - Returns: nil when the content reports no finite, positive height at that width,
        ///   such as in a hostless iOS test bundle.
        public convenience init?(
            _ content: Content, fittingWidth width: CGFloat, visible: Bool = true, scale: CGFloat? = nil,
            appearance: HostedAppearance = HostedAppearance()
        ) {
            precondition(width.isFinite && width > 0)
            guard let height = Self.fittingHeight(of: content, width: width, appearance: appearance) else {
                return nil
            }
            self.init(
                content, size: CGSize(width: width, height: height), visible: visible, scale: scale,
                appearance: appearance)
        }

        /// Hosts a view for the duration of `body`, closing the window afterward.
        ///
        /// The window closes even when `body` throws.
        /// - Parameters:
        ///   - content: The view to render, including any required environment values.
        ///   - size: A finite, positive render size in points.
        ///   - visible: Whether to show the window; lazy content may require visibility.
        ///   - scale: The finite, positive pixels-per-point factor for renders, or nil for
        ///     the display's scale.
        ///   - appearance: Platform appearance overrides.
        ///   - body: Work that renders or inspects the hosted view.
        /// - Returns: The value returned by `body`.
        /// - Throws: Any error thrown by `body`.
        public static func withHostedView<Result>(
            _ content: Content, size: CGSize, visible: Bool = true, scale: CGFloat? = nil,
            appearance: HostedAppearance = HostedAppearance(), _ body: (HostedView) throws -> Result
        ) rethrows -> Result {
            let hosted = HostedView(content, size: size, visible: visible, scale: scale, appearance: appearance)
            defer { hosted.close() }
            return try body(hosted)
        }

        /// Detaches the hosted hierarchy. Repeat calls are harmless; further renders return nil.
        public func close() {
            guard !closed else { return }
            closed = true
            #if HOSTING_APPKIT
                window.contentView = nil
                window.orderOut(nil)
            #else
                window.isHidden = true
                window.rootViewController = nil
            #endif
        }

        /// Performs layout and captures the current rendered frame at the configured scale.
        /// - Returns: PNG bytes, or nil when closed or rendering is unavailable.
        public func renderPNG() -> Data? {
            guard !closed else { return nil }
            layoutWindow()
            return ViewRendering.pngData(of: renderedView, scale: scale)
        }

        /// Compares this render with an explicit caller-owned blank or reference frame.
        ///
        /// Compares encoded bytes exactly. Use ``RenderComparison`` for a pixel tolerance.
        /// - Parameter reference: A comparable PNG produced by the same rendering setup.
        /// - Returns: Whether rendering succeeded and the frame differs from the reference.
        public func rendersDifferently(from reference: Data) -> Bool {
            guard let frame = renderPNG() else {
                return false
            }
            return frame != reference
        }

        /// Pumps the run loop until consecutive rendered frames stop changing.
        ///
        /// Frames are compared as raw pixels without PNG encoding. Stability does not establish
        /// that content arrived; compare with a blank reference separately. Animated views may
        /// never stabilize. Other main-actor tests can interleave.
        /// - Parameters:
        ///   - timeout: The nonnegative monotonic time budget.
        ///   - minimumFrames: The positive number of samples required before success.
        ///   - requiredStableFrames: The positive number of consecutive identical frames.
        ///   - pollInterval: The positive interval between samples.
        /// - Returns: Whether a nonnil render stabilized before the deadline.
        public func waitForStableRender(
            timeout: Duration = .seconds(5), minimumFrames: Int = 8,
            requiredStableFrames: Int = 4, pollInterval: Duration = .seconds(1.0 / 60)
        ) -> Bool {
            guard !closed else { return false }
            return observeStableFrames(
                timeout: timeout, minimumFrames: minimumFrames,
                requiredStableFrames: requiredStableFrames, pollInterval: pollInterval,
                render: {
                    guard !closed else { return nil }
                    layoutWindow()
                    return ViewRendering.pixels(of: renderedView, scale: scale)
                })
        }

        private var renderedView: RenderableView {
            #if HOSTING_APPKIT
                hosting
            #else
                hosting.view
            #endif
        }

        private func layoutWindow() {
            #if HOSTING_APPKIT
                window.layoutIfNeeded()
            #endif
        }

        #if HOSTING_APPKIT
            private static func apply(_ appearance: HostedAppearance, to view: NSView) {
                if let colorScheme = appearance.colorScheme {
                    view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
                }
                if let layoutDirection = appearance.layoutDirection {
                    view.userInterfaceLayoutDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
                }
            }

            private static func fittingHeight(
                of content: Content, width: CGFloat, appearance: HostedAppearance
            ) -> CGFloat? {
                let measuring = NSHostingController(rootView: content)
                apply(appearance, to: measuring.view)
                let height = measuring.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
                return height.isFinite && height > 0 ? height : nil
            }
        #else
            private static func apply(_ appearance: HostedAppearance, to controller: UIViewController) {
                if let colorScheme = appearance.colorScheme {
                    controller.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
                }
                if let layoutDirection = appearance.layoutDirection {
                    controller.traitOverrides.layoutDirection =
                        layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
                }
                if let dynamicTypeSize = appearance.dynamicTypeSize {
                    controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategory(dynamicTypeSize)
                }
            }

            private static func fittingHeight(
                of content: Content, width: CGFloat, appearance: HostedAppearance
            ) -> CGFloat? {
                let measuring = UIHostingController(rootView: content)
                apply(appearance, to: measuring)
                let height = measuring.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
                return height.isFinite && height > 0 ? height : nil
            }
        #endif
    }
#endif
