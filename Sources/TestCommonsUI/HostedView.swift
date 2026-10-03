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
    /// ## Topics
    /// - ``init(_:size:visible:)``
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
        private var closed = false

        /// Creates a window hosting the view and performs its initial layout.
        /// - Parameters:
        ///   - content: The view to render, including any required environment values.
        ///   - size: A finite, positive render size in points.
        ///   - visible: Whether to show the window; lazy content may require visibility.
        public init(_ content: Content, size: CGSize, visible: Bool = true) {
            precondition(size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
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
                window = UIWindow(frame: hosting.view.frame)
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

        /// Performs layout and captures the current rendered frame.
        /// - Returns: PNG bytes, or nil when closed or rendering is unavailable.
        public func renderPNG() -> Data? {
            guard !closed else { return nil }
            #if canImport(AppKit)
                window.layoutIfNeeded()
                return ViewRendering.pngData(of: hosting)
            #elseif canImport(UIKit)
                return ViewRendering.pngData(of: hosting.view)
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
        ///   - timeout: The nonnegative monotonic time budget in seconds.
        ///   - minimumFrames: The positive number of samples required before success.
        ///   - requiredStableFrames: The positive number of consecutive identical frames.
        ///   - pollInterval: The finite, positive interval between samples in seconds.
        /// - Returns: Whether a nonnil render stabilized before the deadline.
        public func waitForStableRender(
            timeout: TimeInterval = 5, minimumFrames: Int = 8,
            requiredStableFrames: Int = 4, pollInterval: TimeInterval = 1.0 / 60
        ) -> Bool {
            guard !closed else { return false }
            return observeStableFrames(
                timeout: timeout, minimumFrames: minimumFrames,
                requiredStableFrames: requiredStableFrames, pollInterval: pollInterval,
                render: { self.renderPNG() })
        }
    }
#endif
