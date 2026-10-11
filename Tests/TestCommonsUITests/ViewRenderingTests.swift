#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    extension RenderingTests {
        @MainActor
        struct ViewRenderingTests {
            @Test(arguments: [1.0, 3.0])
            func offscreenRenderingNeedsNoWindow(scale: CGFloat) throws {
                let size = CGSize(width: 24, height: 16)
                let red = try #require(ViewRendering.pngData(rendering: Color.red, size: size, scale: scale))
                let clear = try #require(ViewRendering.pngData(rendering: Color.clear, size: size, scale: scale))
                #expect(red != clear)
                #expect(pngPixelSize(red) == CGSize(width: 24 * scale, height: 16 * scale))
            }

            @Test func offscreenRenderingDefaultsToOnePixelPerPoint() throws {
                let png = try #require(
                    ViewRendering.pngData(rendering: Text("Ready"), size: CGSize(width: 50, height: 20)))
                #expect(pngPixelSize(png) == CGSize(width: 50, height: 20))
            }

            #if canImport(AppKit)
                @Test func callerOwnedViewsRenderAndStabilize() throws {
                    let hosted = HostedView(Color.blue, size: CGSize(width: 24, height: 24))
                    defer { hosted.close() }
                    let view: RenderableView = hosted.hosting
                    #expect(ViewRendering.pngData(of: view) != nil)
                    let scaled = try #require(ViewRendering.pngData(of: view, scale: 2))
                    #expect(pngPixelSize(scaled) == CGSize(width: 48, height: 48))
                    #expect(
                        ViewRendering.waitForStableRender(
                            view, timeout: .seconds(2), minimumFrames: 2, requiredStableFrames: 2))
                    #expect(!ViewRendering.waitForStableRender(view, timeout: .zero))
                }

                @Test func emptyViewsDoNotRender() {
                    #expect(ViewRendering.pngData(of: NSView(frame: .zero)) == nil)
                    #expect(ViewRendering.pngData(of: NSView(frame: .zero), scale: 2) == nil)
                }
            #else
                @Test func undrawnHierarchiesDoNotReturnBlankBytes() {
                    let hosted = HostedView(Color.blue, size: CGSize(width: 24, height: 24))
                    defer { hosted.close() }
                    #expect(ViewRendering.pngData(of: hosted.hosting.view, scale: 1) == nil)
                    #expect(ViewRendering.pngData(of: UIView(frame: .zero)) == nil)
                }
            #endif
        }
    }
#endif
