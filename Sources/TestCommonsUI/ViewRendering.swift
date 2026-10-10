#if canImport(SwiftUI)
    import Foundation
    import ImageIO
    import SwiftUI
    import UniformTypeIdentifiers
    #if canImport(AppKit)
        import AppKit
    #elseif canImport(UIKit)
        import UIKit
    #endif

    /// Rendering operations for SwiftUI content and caller-owned platform views.
    ///
    /// Keep views attached to their owning window until observation finishes.
    /// On iOS, platform-view capture needs a test target with a host application;
    /// use ``pngData(rendering:size:scale:)`` in hostless package tests.
    ///
    /// ## Topics
    /// - ``pngData(rendering:size:scale:)``
    /// - ``pngData(of:scale:)``
    /// - ``waitForStableRender(_:timeout:minimumFrames:requiredStableFrames:pollInterval:)``
    @MainActor
    public enum ViewRendering {
        /// Renders SwiftUI content offscreen with `ImageRenderer`, without a window.
        ///
        /// Works in hostless test bundles on every platform. Views backed by platform
        /// controls, such as lists, scroll views, and text fields, render as placeholders;
        /// use ``HostedView`` in a hosted test target for those.
        /// - Parameters:
        ///   - content: The view to render, including any required environment values.
        ///   - size: A finite, positive frame size in points.
        ///   - scale: The finite, positive pixels-per-point factor; defaults to 1 so
        ///     output does not depend on the test device.
        /// - Returns: PNG bytes, or nil when the content cannot be rendered.
        public static func pngData<Content: View>(
            rendering content: Content, size: CGSize, scale: CGFloat = 1
        ) -> Data? {
            precondition(size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
            precondition(scale.isFinite && scale > 0)
            let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
            var image: CGImage?
            // `ImageRenderer.cgImage` reuses an uncleared buffer, so transparent pixels can keep a
            // previous render's content. Drawing into a new context starts from transparent pixels.
            renderer.render(rasterizationScale: scale) { renderedSize, draw in
                guard let context = transparentContext(size: renderedSize, scale: scale) else {
                    return
                }
                context.scaleBy(x: scale, y: scale)
                draw(context)
                image = context.makeImage()
            }
            return image.flatMap(pngData(of:))
        }

        /// Lays out and renders a platform view using the platform's native capture API.
        /// - Parameters:
        ///   - view: An attached view whose frame defines the output size.
        ///   - scale: The finite, positive pixels-per-point factor, or nil for the
        ///     display's scale. Pass a fixed value to compare renders across devices.
        /// - Returns: PNG bytes, or nil when the frame cannot be captured. On iOS this is
        ///   nil when the view is not drawn, such as in a test bundle without a host app.
        public static func pngData(of view: RenderableView, scale: CGFloat? = nil) -> Data? {
            precondition(scale.map { $0.isFinite && $0 > 0 } ?? true)
            #if canImport(AppKit)
                view.layoutSubtreeIfNeeded()
                let bounds = view.bounds
                guard !bounds.isEmpty, let bitmap = bitmap(for: view, in: bounds, scale: scale) else {
                    return nil
                }
                view.cacheDisplay(in: bounds, to: bitmap)
                return bitmap.representation(using: .png, properties: [:])
            #elseif canImport(UIKit)
                view.layoutIfNeeded()
                guard !view.bounds.isEmpty else { return nil }
                let format = UIGraphicsImageRendererFormat.preferred()
                if let scale {
                    format.scale = scale
                }
                var drawn = false
                let data = UIGraphicsImageRenderer(size: view.bounds.size, format: format).pngData { _ in
                    drawn = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
                }
                // An undrawn hierarchy still produces valid, blank PNG bytes.
                return drawn ? data : nil
            #endif
        }

        /// Pumps the main run loop until consecutive nonnil rendered frames match.
        ///
        /// Stable pixels may be blank. Serialize tests that pump this run loop.
        /// - Parameters:
        ///   - view: The caller-owned, attached platform view to observe.
        ///   - timeout: The nonnegative monotonic time budget.
        ///   - minimumFrames: The positive minimum number of samples.
        ///   - requiredStableFrames: The positive consecutive identical-frame count.
        ///   - pollInterval: The positive interval between samples.
        /// - Returns: Whether pixels stabilized before the deadline.
        public static func waitForStableRender(
            _ view: RenderableView, timeout: Duration = .seconds(5),
            minimumFrames: Int = 8, requiredStableFrames: Int = 4,
            pollInterval: Duration = .seconds(1.0 / 60)
        ) -> Bool {
            observeStableFrames(
                timeout: timeout, minimumFrames: minimumFrames,
                requiredStableFrames: requiredStableFrames, pollInterval: pollInterval,
                render: { pngData(of: view) })
        }

        #if canImport(AppKit)
            private static func bitmap(for view: NSView, in bounds: CGRect, scale: CGFloat?) -> NSBitmapImageRep? {
                guard let scale else {
                    return view.bitmapImageRepForCachingDisplay(in: bounds)
                }
                let bitmap = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int((bounds.width * scale).rounded(.up)),
                    pixelsHigh: Int((bounds.height * scale).rounded(.up)),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                bitmap?.size = bounds.size
                return bitmap
            }
        #endif

        private static func transparentContext(size: CGSize, scale: CGFloat) -> CGContext? {
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                return nil
            }
            return CGContext(
                data: nil, width: Int((size.width * scale).rounded(.up)),
                height: Int((size.height * scale).rounded(.up)), bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }

        private static func pngData(of image: CGImage) -> Data? {
            let data = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(
                    data, UTType.png.identifier as CFString, 1, nil)
            else {
                return nil
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                return nil
            }
            return data as Data
        }
    }
#endif
