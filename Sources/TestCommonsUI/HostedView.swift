#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    #if canImport(AppKit)
        import AppKit
    #elseif canImport(UIKit)
        import UIKit
    #endif

    /// Owns a real platform hierarchy for rendering a SwiftUI view in tests.
    ///
    /// Call `close()` when finished. Tests pumping the main run loop should be serialized.
    ///
    /// On iOS, SwiftUI builds a hosted hierarchy only in a test target with a host
    /// application. In a hostless package test bundle, renders return nil; use
    /// ``ViewRendering/pngData(rendering:size:scale:)`` there instead.
    ///
    /// ## Topics
    /// - ``init(_:size:visible:scale:)``
    /// - ``hosting``
    /// - ``window``
    /// - ``close()``
    /// - ``renderPNG()``
    /// - ``waitForStableRender(timeout:minimumFrames:requiredStableFrames:pollInterval:)``
    /// - ``rendersDifferently(from:)``
    @MainActor
    public final class HostedView<Content: View> {
        #if canImport(AppKit)
            /// The hosted view or controller; retain its window while observing it.
            public let hosting: NSHostingView<Content>
            /// The owned platform window; use `close()` for coordinated cleanup.
            public let window: NSWindow
        #elseif canImport(UIKit)
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
        public init(_ content: Content, size: CGSize, visible: Bool = true, scale: CGFloat? = nil) {
            precondition(size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
            precondition(scale.map { $0.isFinite && $0 > 0 } ?? true)
            self.scale = scale
            #if canImport(AppKit)
                hosting = NSHostingView(rootView: content)
                hosting.frame = CGRect(origin: .zero, size: size)
                window = NSWindow(
                    contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = hosting
                if visible {
                    window.orderFront(nil)
                }
                window.layoutIfNeeded()
                hosting.layoutSubtreeIfNeeded()
            #elseif canImport(UIKit)
                hosting = UIHostingController(rootView: content)
                hosting.view.frame = CGRect(origin: .zero, size: size)
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

        /// Detaches the hosted hierarchy. Repeat calls are harmless; further renders return nil.
        public func close() {
            guard !closed else { return }
            closed = true
            #if canImport(AppKit)
                window.contentView = nil
                window.orderOut(nil)
            #elseif canImport(UIKit)
                window.isHidden = true
                window.rootViewController = nil
            #endif
        }

        /// Performs layout and captures the current rendered frame at the configured scale.
        /// - Returns: PNG bytes, or nil when closed or rendering is unavailable.
        public func renderPNG() -> Data? {
            guard !closed else { return nil }
            #if canImport(AppKit)
                window.layoutIfNeeded()
                return ViewRendering.pngData(of: hosting, scale: scale)
            #elseif canImport(UIKit)
                return ViewRendering.pngData(of: hosting.view, scale: scale)
            #endif
        }

        /// Compares this render with an explicit caller-owned blank or reference frame.
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
        /// Stability does not establish that content arrived; compare with a blank reference
        /// separately. Animated views may never stabilize. Other main-actor tests can interleave.
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
                render: { self.renderPNG() })
        }
    }
#endif
