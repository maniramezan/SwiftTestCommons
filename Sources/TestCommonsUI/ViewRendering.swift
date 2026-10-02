#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    #if canImport(AppKit)
        import AppKit
        /// A platform view rendered by the hosted-view helpers.
        public typealias RenderableView = NSView
    #elseif canImport(UIKit)
        import UIKit
        /// A platform view rendered by the hosted-view helpers.
        public typealias RenderableView = UIView
    #endif

    /// Rendering operations for caller-owned platform views.
    ///
    /// Keep views attached to their owning window until observation finishes.
    ///
    /// ## Topics
    /// - ``pngData(of:)``
    /// - ``waitForStableRender(_:timeout:minimumFrames:requiredStableFrames:pollInterval:)``
    @MainActor
    public enum ViewRendering {
        /// Lays out and renders a platform view using the platform's native capture API.
        /// - Parameter view: An attached view whose frame defines the output size.
        /// - Returns: PNG bytes, or nil when the frame cannot be captured.
        public static func pngData(of view: RenderableView) -> Data? {
            #if canImport(AppKit)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                return bitmap.representation(using: .png, properties: [:])
            #elseif canImport(UIKit)
                view.layoutIfNeeded()
                guard !view.bounds.isEmpty else { return nil }
                return UIGraphicsImageRenderer(size: view.bounds.size).pngData { _ in
                    view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
                }
            #endif
        }

        /// Pumps the main run loop until consecutive nonnil rendered frames match.
        ///
        /// Stable pixels may be blank. Serialize tests that pump this run loop.
        /// - Parameters:
        ///   - view: The caller-owned, attached platform view to observe.
        ///   - timeout: The finite, nonnegative monotonic budget in seconds.
        ///   - minimumFrames: The positive minimum number of samples.
        ///   - requiredStableFrames: The positive consecutive identical-frame count.
        ///   - pollInterval: The finite, positive sample interval in seconds.
        /// - Returns: Whether pixels stabilized before the deadline.
        public static func waitForStableRender(
            _ view: RenderableView, timeout: TimeInterval = 5,
            minimumFrames: Int = 8, requiredStableFrames: Int = 4,
            pollInterval: TimeInterval = 1.0 / 60
        ) -> Bool {
            observeStableFrames(
                timeout: timeout, minimumFrames: minimumFrames,
                requiredStableFrames: requiredStableFrames, pollInterval: pollInterval,
                render: { pngData(of: view) })
        }
    }

    @MainActor
    func observeStableFrames(
        timeout: TimeInterval, minimumFrames: Int, requiredStableFrames: Int,
        pollInterval: TimeInterval, render: () -> Data?
    ) -> Bool {
        precondition(timeout.isFinite && timeout >= 0 && pollInterval.isFinite && pollInterval > 0)
        precondition(minimumFrames > 0 && requiredStableFrames > 0)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        var previous: Data?
        var stable = 0
        var sampled = 0
        while clock.now < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(pollInterval))
            let frame = render()
            stable = frame != nil && frame == previous ? stable + 1 : (frame == nil ? 0 : 1)
            previous = frame
            sampled += 1
            if sampled >= minimumFrames && stable >= requiredStableFrames { return true }
        }
        return false
    }
#endif
